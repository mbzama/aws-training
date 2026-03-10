'use strict';

/**
 * call-api-with-token.js
 *
 * Generates a signed JWT and calls the protected API endpoint.
 *
 * Usage:
 *   node call-api-with-token.js [sub] [email] [scope] [roles]
 *
 * Examples:
 *   node call-api-with-token.js
 *   node call-api-with-token.js user-123
 *   node call-api-with-token.js user-123 alice@example.com
 *   node call-api-with-token.js user-123 alice@example.com "read:pets"
 *   node call-api-with-token.js user-123 alice@example.com "read:pets write:pets" "user,admin"
 *
 * Environment variables:
 *   JWT_SECRET    - Override the default signing secret
 *   JWT_ALGORITHM - Override the default algorithm (default: HS256)
 *   API_URL       - Override the API base URL
 *   API_PATH      - Override the path to call (default: /pets)
 */

const https = require('https');
const { generateToken } = require('./generate-token');

const API_URL  = process.env.API_URL  || 'https://mamkqj9vr7.execute-api.us-east-1.amazonaws.com';
const API_PATH = process.env.API_PATH || '/prod/pets';

// ── Build payload from CLI args ────────────────────────────────────────────
const [,, sub = 'user-123', email, scope, rolesArg] = process.argv;

const payload = { sub };
if (email)    payload.email = email;
if (scope)    payload.scope = scope;
if (rolesArg) payload.roles = rolesArg.split(',').map(r => r.trim());

// ── Generate token ─────────────────────────────────────────────────────────
let token;
try {
  token = generateToken(payload);
} catch (err) {
  console.error('Failed to generate token:', err.message);
  process.exit(1);
}

console.log('Payload:', JSON.stringify(payload));
console.log('Token:', token);
console.log(`\nCalling ${API_URL}${API_PATH} ...\n`);

// ── Make the HTTP request ──────────────────────────────────────────────────
const url = new URL(API_PATH, API_URL);

const options = {
  hostname: url.hostname,
  path:     url.pathname + url.search,
  method:   'GET',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Accept':        'application/json',
  },
};

const req = https.request(options, (res) => {
  const statusEmoji = res.statusCode >= 200 && res.statusCode < 300 ? '✅' : '❌';
  console.log(`${statusEmoji}  HTTP ${res.statusCode} ${res.statusMessage}`);
  console.log('Headers:', JSON.stringify(res.headers, null, 2));

  let body = '';
  res.on('data', chunk => { body += chunk; });
  res.on('end', () => {
    console.log('\nResponse body:');
    try {
      console.log(JSON.stringify(JSON.parse(body), null, 2));
    } catch {
      console.log(body);
    }
  });
});

req.on('error', (err) => {
  console.error('Request failed:', err.message);
  process.exit(1);
});

req.end();
