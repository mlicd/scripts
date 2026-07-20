# Okta Event Types Reference

Helpful for event analysis in your SIEM.
Event types that commonly appear in `eventType_s`

## Authentication Events

| Event Type | Description |
|---|---|
| `user.session.start` | User initiated a new Okta session (primary authentication) |
| `user.session.end` | User session ended (logout or expiry) |
| `user.authentication.sso` | User was granted SSO access to an application |
| `user.authentication.auth_via_mfa` | User completed an MFA challenge |
| `user.authentication.auth_via_IDP` | User authenticated via an external identity provider |
| `user.authentication.auth_via_social` | User authenticated via a social login (Google, etc.) |
| `user.authentication.verify` | Okta verified user credentials |

## MFA-Specific Events

| Event Type | Description |
|---|---|
| `user.mfa.factor.activate` | User enrolled a new MFA factor |
| `user.mfa.factor.deactivate` | User removed an MFA factor |
| `user.mfa.factor.update` | MFA factor was modified |
| `user.mfa.attempt_bypass` | MFA was bypassed (admin override or policy skip) |
| `user.mfa.okta_verify.deny_push` | User denied an Okta Verify push notification |

## Application Events

| Event Type | Description |
|---|---|
| `app.auth.sso` | Application-level SSO token was issued |
| `app.auth.token.grant.access_token` | OAuth access token was granted |
| `app.auth.token.grant.id_token` | OIDC ID token was granted |
| `app.auth.token.grant.refresh_token` | OAuth refresh token was granted |
| `app.oauth2.as.token.grant` | Authorization server issued a token |
| `app.oauth2.as.authorize` | User authorized an OAuth app |

## Policy Evaluation Events

| Event Type | Description |
|---|---|
| `policy.evaluate_sign_on` | Sign-on policy was evaluated for the session |
| `policy.rule.evaluate` | A specific policy rule was evaluated |

## User Lifecycle Events

| Event Type | Description |
|---|---|
| `user.lifecycle.activate` | User account was activated |
| `user.lifecycle.deactivate` | User account was deactivated |
| `user.lifecycle.suspend` | User account was suspended |
| `user.lifecycle.unsuspend` | User account was unsuspended |
| `user.lifecycle.create` | New user account was created |
| `user.account.lock` | Account was locked (too many failed attempts) |
| `user.account.unlock` | Account was unlocked |
| `user.credential.password.update` | User changed their password |
| `user.credential.password.reset` | Password was reset (by admin or self-service) |

## Security Events

| Event Type | Description |
|---|---|
| `security.threat.detected` | Okta ThreatInsight flagged suspicious activity |
| `security.session.detect` | Anomalous session behavior detected |
| `user.account.report_suspicious_activity_by_enduser` | User reported they did not perform an action |

---

## Outcome Values

Each event has a `Result` column (from `outcome_result_s`):

| Value | Meaning |
|---|---|
| `SUCCESS` | Action completed successfully |
| `FAILURE` | Action failed (see `outcome_reason_s` for detail) |
| `SKIPPED` | Action was skipped by policy |
| `UNKNOWN` | Outcome could not be determined |

## Common Failure Reasons (`outcome_reason_s`)

| Reason | Context |
|---|---|
| `INVALID_CREDENTIALS` | Wrong username or password |
| `MFA_ENROLL_REQUIRED` | User hasn't enrolled in required MFA |
| `MFA_TIMEOUT` | MFA challenge expired |
| `LOCKED_OUT` | Account is locked |
| `NETWORK_ZONE_BLACKLISTED` | Request came from a blocked network zone |
| `FACTOR_NOT_SETUP` | Required factor isn't configured |
| `AUTH_DENIED` | Authentication denied by policy |
