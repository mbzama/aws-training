/**
 * AWS API Gateway Lambda Authorizer (Token-Based)
 *
 * Validates a JWT Bearer token from the Authorization header.
 * Returns an IAM policy allowing or denying access to the API.
 *
 * Authorizer type: TOKEN
 * Token source:    method.request.header.Authorization
 */

'use strict';

const jwt = require('jsonwebtoken');

// ---------------------------------------------------------------------------
// Configuration  (inject via Lambda environment variables)
// ---------------------------------------------------------------------------
const JWT_SECRET     = process.env.JWT_SECRET;          // HMAC secret OR public key PEM
const JWT_ALGORITHM  = process.env.JWT_ALGORITHM  || 'HS256';
const JWT_ISSUER     = process.env.JWT_ISSUER     || undefined; // e.g. 'https://auth.example.com'
const JWT_AUDIENCE   = process.env.JWT_AUDIENCE   || undefined; // e.g. 'my-api'
// ALLOWED_SCOPES is read inside the handler so env changes take effect per-invocation

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------
exports.handler = async (event) => {
  // Redact the token from logs
  const safeEvent = { ...event, authorizationToken: '[REDACTED]' };
  if (event.headers?.authorization) safeEvent.headers = { ...event.headers, authorization: '[REDACTED]' };
  console.log('Authorizer invoked:', JSON.stringify(safeEvent));

  // Support both:
  //   REST API v1 TOKEN authorizer  → event.authorizationToken
  //   HTTP API v2 REQUEST authorizer → event.headers.authorization (lowercase)
  const rawAuthHeader = event.authorizationToken
    || event.headers?.authorization
    || event.headers?.Authorization;

  const token = extractBearerToken(rawAuthHeader);

  if (!token) {
    // Returning 'Unauthorized' triggers a 401 to the caller
    throw new Error('Unauthorized');
  }

  let decoded;
  try {
    decoded = verifyToken(token);
  } catch (err) {
    console.warn('Token verification failed:', err.message);
    // 'Unauthorized' → 401; any other string → 403
    throw new Error('Unauthorized');
  }

  // HTTP API v2 uses routeArn; REST API v1 uses methodArn
  const resourceArn = event.routeArn || event.methodArn;

  // Optional scope check — read env var dynamically so Lambda picks up updates without redeploy
  const allowedScopes = process.env.ALLOWED_SCOPES
    ? process.env.ALLOWED_SCOPES.split(',').map(s => s.trim())
    : [];

  if (allowedScopes.length > 0 && !hasRequiredScopes(decoded, allowedScopes)) {
    console.warn('Insufficient scopes. Required:', allowedScopes, 'Got:', decoded.scope || decoded.scopes);
    return generatePolicy(decoded.sub, 'Deny', resourceArn, decoded);
  }

  return generatePolicy(decoded.sub, 'Allow', resourceArn, decoded);
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Extract the raw JWT from a "Bearer <token>" string.
 * Returns null if the header is missing or malformed.
 */
function extractBearerToken(authHeader) {
  if (!authHeader) return null;
  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0].toLowerCase() !== 'bearer') return null;
  return parts[1];
}

/**
 * Verify and decode the JWT.
 * Throws on invalid signature, expiry, issuer, or audience mismatch.
 */
function verifyToken(token) {
  if (!JWT_SECRET) {
    throw new Error('JWT_SECRET environment variable is not set');
  }

  const options = { algorithms: [JWT_ALGORITHM] };
  if (JWT_ISSUER)   options.issuer   = JWT_ISSUER;
  if (JWT_AUDIENCE) options.audience = JWT_AUDIENCE;

  return jwt.verify(token, JWT_SECRET, options);
}

/**
 * Check that the decoded token contains all required scopes.
 * Supports both space-separated string and array formats.
 */
function hasRequiredScopes(decoded, required) {
  const tokenScopes = Array.isArray(decoded.scope)
    ? decoded.scope
    : (decoded.scope || '').split(' ');

  return required.every(s => tokenScopes.includes(s));
}

/**
 * Build an IAM policy document for API Gateway.
 *
 * @param {string} principalId  - Unique identifier for the caller (e.g. user ID)
 * @param {string} effect       - 'Allow' | 'Deny'
 * @param {string} methodArn    - The ARN of the invoked API method
 * @param {object} decoded      - Decoded JWT claims (forwarded as context)
 */
function generatePolicy(principalId, effect, methodArn, decoded = {}) {
  // Wildcard the resource to cache the policy for all routes in this stage.
  // REST API v1  methodArn format: arn:aws:execute-api:{region}:{acct}:{apiId}/{stage}/{method}/{resource}
  // HTTP API v2  routeArn  format: arn:aws:execute-api:{region}:{acct}:{apiId}/{stage}/{method}/{route}
  const resourceArn = methodArn.replace(/\/[^/]+\/[^/]+$/, '/*/*');

  const policy = {
    principalId,
    policyDocument: {
      Version: '2012-10-17',
      Statement: [
        {
          Action: 'execute-api:Invoke',
          Effect: effect,
          Resource: resourceArn,
        },
      ],
    },
    // Context is forwarded to the integrated Lambda / backend as
    // $context.authorizer.<key>  (string values only)
    context: {
      userId:   String(decoded.sub   || ''),
      email:    String(decoded.email || ''),
      roles:    JSON.stringify(decoded.roles  || []),
      scopes:   JSON.stringify(decoded.scope  || []),
    },
  };

  console.log('Returning policy:', JSON.stringify({ ...policy, policyDocument: policy.policyDocument }));
  return policy;
}
