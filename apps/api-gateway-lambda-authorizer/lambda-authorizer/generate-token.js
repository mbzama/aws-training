'use strict';

const jwt = require('jsonwebtoken');

const SECRET    = process.env.JWT_SECRET    || '53eeaea9fdf15337ee957a5fd126a6db39cfb1f20b5504c12ec99ffde079d3ad';
const ALGORITHM = process.env.JWT_ALGORITHM || 'HS256';

/**
 * Generate a signed JWT valid for 1 hour.
 *
 * @param {object} payload  - Claims to embed (sub, email, scope, roles, etc.)
 * @returns {string}          Signed JWT string
 */
function generateToken(payload = {}) {
  if (!payload.sub) throw new Error('payload.sub (user ID) is required');

  return jwt.sign(payload, SECRET, {
    algorithm: ALGORITHM,
    expiresIn: '1h',
  });
}

// ── CLI usage ──────────────────────────────────────────────────────────────
// node generate-token.js <sub> [email] [scope] [roles]
//
// Examples:
//   node generate-token.js user-123
//   node generate-token.js user-123 alice@example.com
//   node generate-token.js user-123 alice@example.com "read:pets write:pets"
//   node generate-token.js user-123 alice@example.com "read:pets" "user,admin"
// ──────────────────────────────────────────────────────────────────────────
if (require.main === module) {
  const [,, sub, email, scope, rolesArg] = process.argv;

  if (!sub) {
    console.error('Usage: node generate-token.js <sub> [email] [scope] [roles]');
    console.error('  sub    - User ID (required)');
    console.error('  email  - User email (optional)');
    console.error('  scope  - Space-separated scopes (optional), e.g. "read:pets write:pets"');
    console.error('  roles  - Comma-separated roles (optional), e.g. "user,admin"');
    process.exit(1);
  }

  const payload = { sub };
  if (email)    payload.email  = email;
  if (scope)    payload.scope  = scope;
  if (rolesArg) payload.roles  = rolesArg.split(',').map(r => r.trim());

  const token = generateToken(payload);

  console.log('\nToken (expires in 1h):');
  console.log(token);
  console.log('\ncurl command:');
  console.log(`curl -i -H "Authorization: Bearer ${token}" https://mamkqj9vr7.execute-api.us-east-1.amazonaws.com/prod/pets`);
}

module.exports = { generateToken };
