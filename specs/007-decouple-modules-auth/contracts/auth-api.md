# Authentication API Contract

**Feature**: specs/007-decouple-modules-auth
**Version**: 1.0
**Generated**: 2026-09-12
**Source**: Plan.md Phase 1 Design

---

## Base URL

| Environment | Base URL |
|-------------|----------|
| Workshop Local | `http://localhost:8087/api/auth` |
| ai_interviewing Local | `http://localhost:8099/api/auth` |
| Production | `https://<domain>/api/auth` |

---

## Endpoints

### POST /login

Authenticate user and create session.

**Request**:
```json
{
  "username": "string (required, min: 3, max: 100)",
  "password": "string (required, min: 8)"
}
```

**Response 200 OK**:
```json
{
  "token": "string (base64url, 43 chars)",
  "expires_at": "string (ISO 8601, RFC3339)",
  "user": {
    "id": "string (UUID)",
    "username": "string",
    "role": "string (admin|user)"
  },
  "permissions": [
    {
      "resource": "string",
      "actions": ["read", "write", "delete"]
    }
  ]
}
```

**Response 401 Unauthorized**:
```json
{
  "error": "invalid_credentials",
  "message": "Invalid username or password"
}
```

**Response 429 Too Many Requests**:
```json
{
  "error": "rate_limited",
  "message": "Too many login attempts. Try again in 60 seconds.",
  "retry_after": 60
}
```

**Rate Limit**: 5 attempts per minute per IP

---

### POST /logout

Revoke current session.

**Headers**: `Authorization: Bearer <token>`

**Request**: Empty body

**Response 200 OK**:
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

**Response 401 Unauthorized**: Invalid or expired token

---

### POST /refresh

Refresh access token (extend session).

**Headers**: `Authorization: Bearer <token>`

**Request**: Empty body

**Response 200 OK**:
```json
{
  "token": "string (new base64url token)",
  "expires_at": "string (ISO 8601, extended by 24h)"
}
```

**Response 401 Unauthorized**: Token expired or revoked

---

### GET /me

Get current user info and permissions.

**Headers**: `Authorization: Bearer <token>`

**Response 200 OK**:
```json
{
  "user": {
    "id": "string (UUID)",
    "username": "string",
    "role": "string (admin|user)"
  },
  "module": "string (workshop|ai_interviewing)",
  "permissions": [
    {
      "resource": "string",
      "actions": ["read", "write", "delete"]
    }
  ]
}
```

---

### POST /switch

Switch to different account (logout + login in one call).

**Request**:
```json
{
  "username": "string (required)",
  "password": "string (required)"
}
```

**Response 200 OK**: Same as `/login`

**Response 401 Unauthorized**: Invalid credentials

**Note**: Revokes all existing sessions for the current user before creating new one.

---

## Error Responses

All errors follow RFC 7807 Problem Details format:

```json
{
  "type": "string (URI reference)",
  "title": "string",
  "status": "integer (HTTP status)",
  "detail": "string",
  "instance": "string (request path)"
}
```

**Common Errors**:
| Status | Type | Title | When |
|--------|------|-------|------|
| 400 | `validation_error` | Invalid Request | Malformed JSON, missing fields |
| 401 | `unauthorized` | Unauthorized | Invalid/expired/revoked token |
| 403 | `forbidden` | Forbidden | Insufficient permissions |
| 429 | `rate_limited` | Too Many Requests | Rate limit exceeded |
| 500 | `internal_error` | Internal Server Error | Unexpected server error |

---

## Security Requirements

1. **Password Hashing**: bcrypt cost 12 or argon2id
2. **Token Generation**: crypto/rand 32 bytes, base64url encoded
3. **Token Storage**: SHA-256 hash in database (never plain text)
4. **HTTPS Only**: All auth endpoints require TLS in production
5. **CORS**: Restricted to known origins
6. **CSRF**: SameSite=Strict cookies for browser clients
7. **Rate Limiting**: Per-IP on login, per-user on refresh
8. **Audit Logging**: All auth events logged with IP, user-agent, timestamp

---

## Module-Specific Permissions

### Workshop (module: "workshop")

| Role | Resource | Actions |
|------|----------|---------|
| admin | all | read, write, delete |
| user | all | read, write, delete |

**Both users have identical full access.**

### ai_interviewing (module: "ai_interviewing")

| Role | Resource | Actions |
|------|----------|---------|
| admin | knowledge_base | read, write |
| admin | progress | read, write |
| admin | employer_data | read |
| admin | github_analysis | read |
| user | knowledge_base | read |
| user | progress | read, write |

**User "rami" (role=user) CANNOT access employer_data or github_analysis.**