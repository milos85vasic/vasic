# Contract: roles API (spec 023)

| Request | Anonymous | Student (`role` `user`) | Administrator (`role` `admin`) |
|---|---|---|---|
| `GET /api/account` | 401 | 200 `{username, role, role_label, must_change_password}` | 200 |
| `POST /api/account/password` `{current_password, new_password}` | 401 | 200 (ends all sessions of the account, clears the flag); 400 `weak_password` naming the required minimum, never the value; 429 after 5 wrong current passwords in 10 minutes | same |
| `GET /api/admin/users` | 401 | 403 `forbidden` | 200 `{users:[{username, role, role_label, must_change_password, created_at, last_login}]}` (no hashes) |
| any path under `/api/admin/` (even nonexistent) | 401 | 403 | routed normally (404 if absent) |
| any other `/api/*` while `must_change_password` is set | 401 | 403 `password_change_required` (only the two account endpoints are allowed) | n/a (administrators are not flagged) |

`role_label` is `administrator` for `admin` and `student` for `user`. Extension point: `authhttp.RegisterAdminOnly(method, prefix)`.
Password policy: minimum length from `WORKSHOP_PASSWORD_MIN_LEN` (6..72, default 8); an invalid value refuses every password.
