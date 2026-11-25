# Karipa password recovery

The login screen opens `/forgot_password`. Its route owns the email, code,
new-password, and confirmation stages. It reuses `KaripaAuthLayout`,
`KaripaButton`, `KaripaFeedback`, and the current theme. Registration email
verification retains its existing `/otp` route. Recovery never signs the user
in automatically or stores a reset authorization in device preferences.

## Configuration and deployment

Use the existing backend environment configuration. Required variables:

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL`, `DIRECT_URL` | Existing PostgreSQL runtime and migration connections |
| `JWT_SECRET` | Existing JWT signing secret |
| `PASSWORD_RECOVERY_SECRET` | Independent, high-entropy secret of at least 32 bytes for keyed challenge and rate-limit hashes |
| `SMTP_HOST` | Existing SMTP server |
| `SMTP_PORT` | SMTP port; defaults to 587 |
| `SMTP_SECURE` | `true` for implicit TLS (usually 465); otherwise STARTTLS is required |
| `SMTP_USER`, `SMTP_PASS` | SMTP credentials |
| `SMTP_FROM` | Provider-approved sender, e.g. `Karipa <no-reply@your-domain>` |

Generate a recovery secret locally with
`node -e "process.stdout.write(require('node:crypto').randomBytes(32).toString('hex'))"`
and install it in your secret store; do not commit it or log it. All API replicas
must share the same secret. Rotation invalidates outstanding recovery sessions
and changes rate-limit keys. Use HTTPS for the public API and SMTP TLS.

From `backend/`, run `npx prisma migrate deploy`, `npm run prisma:generate`, and
`npm run build`, then restart the backend. Migration
`20261125_password_recovery` adds `tbl_users.session_version` (default zero),
`password_recovery`, and `recovery_rate_limits`. It preserves account data and
passwords. Existing JWTs remain valid at version zero until that account resets
its password. There are no refresh tokens in this authentication system.

The shared email helper now fails on missing SMTP configuration, rejected mail,
or SMTP errors, including registration email delivery. The old mock-success and
OTP-logging fallback was removed. SMTP acceptance is not a guarantee that a
message reaches an inbox; check provider delivery/bounce monitoring. Recovery
errors never include provider exceptions, passwords, codes, or authorizations.

The local migration was applied during implementation. A recovery secret was
generated in the ignored local `backend/.env` without displaying it. SMTP
connection and authentication were verified, but no email was sent and inbox
delivery remains untested. Restart the backend to load the new environment
variable. Configure the secret and provider credentials separately for deployed
environments. No existing account password was reset for testing.

## API

All endpoints are POST under `/api/auth/password`, return JSON, and set
`Cache-Control: no-store`.

| Endpoint | Request | Successful response |
| --- | --- | --- |
| `/request` | `email` | Generic message, opaque `challengeId`, remaining `expiresIn` (up to 600 seconds), `resendAfter` (up to 60 seconds) |
| `/resend` | `email` | Same as request; replaces the previous challenge |
| `/verify` | `challengeId`, six-digit `otp` | 256-bit `authorization`, `expiresIn: 300` |
| `/reset` | `challengeId`, `authorization`, `password` | Reset confirmation |

Request/resend produce the same response and send the same generic recovery
email for existing and unknown addresses. This prevents SMTP timing and delivery
errors from disclosing account existence. Unknown-account challenges cannot
verify or reset a password. This deliberate tradeoff means unknown addresses can
receive recovery mail; shared IP/email limits control mail volume. Account lookup
retains the existing exact email matching behavior; enter the email as registered.

Codes use Node cryptographic randomness, expire after 10 minutes, and allow at
most five valid-format verification attempts, including concurrent attempts.
Codes are stored as challenge-bound HMAC-SHA256 hashes using a separate server
secret, protecting the six-digit search space if only the database is exposed.
Delivery failure leaves no usable OTP. Resends require 60 seconds and invalidate
both earlier codes and earlier reset authorizations.

Verification issues a five-minute, single-use authorization bound to the
challenge and account. Only its keyed hash is persisted. The reset transaction
consumes it, hashes the new password with bcrypt cost 12, clears registration
codes, invalidates every account recovery challenge, and increments the session
version. Every authenticated request checks that version against the database.
Serializable PostgreSQL transactions with bounded conflict retries protect
attempt counting, resend replacement, and concurrent resets. Database failures
fail closed.

Passwords retain the existing minimum of eight characters. Reset also rejects
passwords longer than bcrypt's 72 UTF-8 byte limit rather than silently truncating
them. Email alone cannot authorize a reset.

## Limits and operations

Database-backed 15-minute fixed windows apply separately per operation:

- 30 requests per IP; request and resend share a bucket.
- 5 request/resend operations per normalized email.
- 10 verify operations per challenge and 10 reset operations per challenge.
- The independent five-attempt OTP limit and 60-second issuance cooldown also apply.

Limit responses include `Retry-After` and a JSON `retryAfter` in seconds. Limits
survive process restarts and work across replicas. The default Express direct
peer IP is used. If deploying behind a reverse proxy, configure **only trusted
proxy addresses** in Express so `req.ip` identifies clients. Do not blindly trust
client-controlled forwarded headers. Without proxy configuration, clients behind
one proxy share its IP allowance.

Expired limit rows and old challenge rows may be removed by a scheduled database
maintenance task. Retain challenge rows for at least their issuance cooldown;
deleting still-active rows weakens cooldown enforcement. Suggested retention:
delete `recovery_rate_limits` rows whose `expires_at` is over a day old, and
`password_recovery` rows whose `expires_at` is over a day old. Neither table stores
raw email addresses, OTPs, passwords, or reset authorizations.

For application rollback, retain these additive database fields/tables and
session-version validation; do not deploy an older authentication middleware
that would make revoked JWTs valid again. A forward fix is preferable after any
real password reset. Dropping the recovery tables discards only recovery/limit
state, but dropping the session version removes revocation history.

## Focused verification

From `backend/`:

```powershell
npm run build
npm test -- src/tests/passwordRecovery.test.ts src/tests/passwordRecovery.routes.test.ts src/tests/recoveryEmail.test.ts src/tests/profileValidation.test.ts
$env:RUN_RECOVERY_DB_TESTS='true'
npm test -- src/tests/passwordRecovery.database.test.ts
```

The opt-in PostgreSQL test creates and removes one fixture account using an
`example.invalid` email. Email delivery is stubbed only inside tests. It races
two resets, asserts exactly one succeeds, checks the winning bcrypt password,
rejects replay, and verifies all challenges are consumed. It never changes an
existing account or sends real email.

From `mobile/`, with existing resolved dependencies:

```powershell
flutter analyze --no-pub
flutter test --no-pub test/password_recovery_test.dart test/password_recovery_service_test.dart test/karipa_auth_ui_test.dart test/auth_service_login_test.dart test/auth_session_restore_test.dart
```

Widget tests exercise validation, masking, loading, server errors, confirmation,
and preserved sign-in/guest/registration controls. Layout tests cover narrow
phones, landscape, and tablet-sized constraints, light/dark themes, 200% text,
and keyboard insets. These checks do not establish Android runtime, TalkBack,
VoiceOver, or real inbox delivery. No Android device or AVD was available during
implementation; native screenshots and screen-reader checks remain unverified.

Implementation verification: backend build and TypeScript no-emit analysis passed;
29 focused backend tests and one real PostgreSQL concurrency test passed. All 34
focused Flutter tests passed. `flutter analyze --no-pub` reports ten pre-existing
info-level style/deprecation diagnostics in login, registration, and ready-to-start
screens, with no errors or warnings. `git diff --check` passed, dependencies and
the local Flutter lockfile were unchanged, and hot reload succeeded. An independent
Impeccable source review cleared its requested fixes; rendered/native approval
remains unavailable. The SMTP authentication check sent no email.

Transaction handling follows the installed Prisma 6 serializable transaction
and conflict-retry guidance ([Prisma documentation](https://www.prisma.io/docs/orm/v6/prisma-client/queries/transactions));
random generation and constant-time digest comparison use the Node crypto APIs
([Node documentation](https://nodejs.org/api/crypto.html)).
