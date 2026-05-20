'use strict';

const jwt = require('jsonwebtoken');

const SECRET = 'test-secret-key-minimum-32-chars!!';

// Set env vars before requiring the handler
process.env.JWT_SECRET    = SECRET;
process.env.JWT_ALGORITHM = 'HS256';

const { handler }       = require('./index');
const { generateToken } = require('./generate-token');

// Helper to build a mock API GW authorizer event
function buildEvent(token) {
  return {
    type: 'TOKEN',
    authorizationToken: token ? `Bearer ${token}` : undefined,
    methodArn: 'arn:aws:execute-api:us-east-1:123456789012:abc123def4/prod/GET/pets',
  };
}

function makeToken(payload, expiresIn = '1h') {
  return jwt.sign(payload, SECRET, { algorithm: 'HS256', expiresIn });
}

describe('Lambda Authorizer', () => {
  test('allows a valid JWT', async () => {
    const token = makeToken({ sub: 'user-42', email: 'user@example.com' });
    const result = await handler(buildEvent(token));

    expect(result.principalId).toBe('user-42');
    expect(result.policyDocument.Statement[0].Effect).toBe('Allow');
    expect(result.context.userId).toBe('user-42');
    expect(result.context.email).toBe('user@example.com');
  });

  test('denies an expired JWT', async () => {
    const token = makeToken({ sub: 'user-42' }, '-1s'); // already expired
    await expect(handler(buildEvent(token))).rejects.toThrow('Unauthorized');
  });

  test('throws Unauthorized when no token is provided', async () => {
    await expect(handler(buildEvent(null))).rejects.toThrow('Unauthorized');
  });

  test('throws Unauthorized when token has wrong format', async () => {
    const event = { ...buildEvent('valid'), authorizationToken: 'NotBearer abc' };
    await expect(handler(event)).rejects.toThrow('Unauthorized');
  });

  test('throws Unauthorized for an invalid signature', async () => {
    const token = jwt.sign({ sub: 'hacker' }, 'wrong-secret', { algorithm: 'HS256' });
    await expect(handler(buildEvent(token))).rejects.toThrow('Unauthorized');
  });

  test('denies when required scopes are missing', async () => {
    process.env.ALLOWED_SCOPES = 'read:admin';
    const token = makeToken({ sub: 'user-42', scope: 'read:user' });
    const result = await handler(buildEvent(token));

    expect(result.policyDocument.Statement[0].Effect).toBe('Deny');
    delete process.env.ALLOWED_SCOPES;
  });

  test('allows when required scopes are present', async () => {
    process.env.ALLOWED_SCOPES = 'read:user';
    const token = makeToken({ sub: 'user-42', scope: 'read:user write:user' });
    const result = await handler(buildEvent(token));

    expect(result.policyDocument.Statement[0].Effect).toBe('Allow');
    delete process.env.ALLOWED_SCOPES;
  });

  test('policy resource uses wildcard ARN for caching', async () => {
    const token = makeToken({ sub: 'user-1' });
    const result = await handler(buildEvent(token));
    expect(result.policyDocument.Statement[0].Resource).toMatch(/\*\/\*$/);
  });
});

// ---------------------------------------------------------------------------
// generateToken tests
// ---------------------------------------------------------------------------
describe('generateToken', () => {
  test('returns a valid signed JWT', () => {
    const token = generateToken({ sub: 'user-1' });
    console.log('[generateToken] valid JWT:', token);
    const decoded = jwt.verify(token, SECRET, { algorithms: ['HS256'] });

    expect(decoded.sub).toBe('user-1');
  });

  test('token expires in ~1 hour', () => {
    const before = Math.floor(Date.now() / 1000);
    const token   = generateToken({ sub: 'user-1' });
    const decoded = jwt.decode(token);
    console.log('[generateToken] expires in ~1h — iat:', decoded.iat, 'exp:', decoded.exp, 'ttl:', decoded.exp - decoded.iat, 's');

    expect(decoded.exp - decoded.iat).toBe(3600);
    expect(decoded.iat).toBeGreaterThanOrEqual(before);
  });

  test('embeds email, scope, and roles in the payload', () => {
    const token = generateToken({
      sub:   'user-2',
      email: 'bob@example.com',
      scope: 'read:pets write:pets',
      roles: ['user', 'admin'],
    });
    console.log('[generateToken] with claims:', token);
    const decoded = jwt.decode(token);

    expect(decoded.email).toBe('bob@example.com');
    expect(decoded.scope).toBe('read:pets write:pets');
    expect(decoded.roles).toEqual(['user', 'admin']);
  });

  test('throws when sub is missing', () => {
    expect(() => generateToken({ email: 'no-sub@example.com' })).toThrow('payload.sub');
  });

  test('generated token is accepted by the authorizer handler', async () => {
    const token  = generateToken({ sub: 'user-99', email: 'gen@example.com' });
    console.log('[generateToken] accepted by handler:', token);
    const result = await handler(buildEvent(token));

    expect(result.principalId).toBe('user-99');
    expect(result.policyDocument.Statement[0].Effect).toBe('Allow');
    expect(result.context.email).toBe('gen@example.com');
  });
});
