# Progress Tracking API Contract

**Feature**: specs/007-decouple-modules-auth
**Version**: 1.0
**Generated**: 2026-09-12
**Source**: Plan.md Phase 1 Design

---

## Base URL

| Environment | Base URL |
|-------------|----------|
| Workshop Local | `http://localhost:8087/api/progress` |
| ai_interviewing Local | `http://localhost:8099/api/progress` |
| Production | `https://<domain>/api/progress` |

---

## Headers

All endpoints require:
- `Authorization: Bearer <token>` — Valid session token
- `Content-Type: application/json`

---

## Data Structures

### ProgressRecord (Response)
```json
{
  "id": "string (UUID)",
  "user_id": "string (UUID)",
  "module_id": "string (UUID)",
  "area_id": "string",
  "lesson_id": "string",
  "item_type": "string (lesson|test|exercise)",
  "item_id": "string",
  "completed": "boolean",
  "score": "integer|null (0-100, only for tests)",
  "completed_at": "string|null (ISO 8601)",
  "created_at": "string (ISO 8601)",
  "updated_at": "string (ISO 8601)"
}
```

### ProgressSummary (Response)
```json
{
  "areas": {
    "area_id": {
      "name": "string",
      "lessons": {
        "lesson_id": {
          "name": "string",
          "total_items": "integer",
          "completed_items": "integer",
          "completion_rate": "number (0.0-1.0)",
          "avg_score": "number|null",
          "items": [
            {
              "type": "lesson|test|exercise",
              "id": "string",
              "completed": "boolean",
              "score": "integer|null"
            }
          ]
        }
      },
      "total_items": "integer",
      "completed_items": "integer",
      "completion_rate": "number (0.0-1.0)"
    }
  },
  "overall": {
    "total_items": "integer",
    "completed_items": "integer",
    "completion_rate": "number (0.0-1.0)",
    "avg_score": "number|null"
  }
}
```

---

## Endpoints

### GET /

Get all progress records for authenticated user in current module.

**Query Parameters**:
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `area_id` | string | No | Filter by area |
| `lesson_id` | string | No | Filter by lesson (requires area_id) |
| `item_type` | string | No | Filter by type (lesson|test|exercise) |
| `completed` | boolean | No | Filter by completion status |

**Response 200 OK**:
```json
{
  "records": [ProgressRecord],
  "total": "integer"
}
```

---

### GET /summary

Get aggregated progress summary for authenticated user.

**Response 200 OK**: `ProgressSummary`

---

### GET /:areaId/:lessonId

Get progress for specific lesson (all items within lesson).

**Path Parameters**:
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `areaId` | string | Yes | Area identifier |
| `lessonId` | string | Yes | Lesson identifier |

**Response 200 OK**:
```json
{
  "area_id": "string",
  "lesson_id": "string",
  "items": [ProgressRecord],
  "summary": {
    "total": "integer",
    "completed": "integer",
    "completion_rate": "number"
  }
}
```

**Response 404 Not Found**: Area or lesson not found

---

### GET /:recordId

Get single progress record by ID.

**Path Parameters**:
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `recordId` | string (UUID) | Yes | Progress record ID |

**Response 200 OK**: `ProgressRecord`

**Response 404 Not Found**: Record not found or not owned by user

---

### POST /

Create or update progress record (upsert).

**Request**:
```json
{
  "area_id": "string (required, max: 100)",
  "lesson_id": "string (required, max: 100)",
  "item_type": "string (required, enum: lesson|test|exercise)",
  "item_id": "string (required, max: 100)",
  "completed": "boolean (required)",
  "score": "integer (optional, 0-100, only for tests)"
}
```

**Validation**:
- `score` required when `item_type = "test"` and `completed = true`
- `score` must be 0-100
- `score` ignored for non-test types

**Response 201 Created** (new record) / **200 OK** (updated):
```json
ProgressRecord
```

**Response 400 Bad Request**:
```json
{
  "error": "validation_error",
  "details": [
    {"field": "score", "message": "Score required for completed tests"}
  ]
}
```

**Response 403 Forbidden**: User lacks write permission for progress resource

---

### PUT /:recordId

Update existing progress record.

**Path Parameters**:
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `recordId` | string (UUID) | Yes | Progress record ID |

**Request** (partial update):
```json
{
  "completed": "boolean (optional)",
  "score": "integer (optional, 0-100)"
}
```

**Response 200 OK**: `ProgressRecord`

**Response 403 Forbidden**: Not owner or no write permission

**Response 404 Not Found**: Record not found

---

### DELETE /:recordId

Delete progress record (reset to not started).

**Path Parameters**:
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `recordId` | string (UUID) | Yes | Progress record ID |

**Response 204 No Content**

**Response 403 Forbidden**: Not owner or no delete permission

**Response 404 Not Found**: Record not found

---

## Module-Specific Behavior

### Workshop

- Areas = Chapters (e.g., "intro", "advanced", "expert")
- Lessons = Chapter sections
- Items = Lessons, exercises, quizzes
- Progress synced with chapter/lesson structure from `chapters/`

### ai_interviewing

- Areas = Knowledge domains (e.g., "ml-fundamentals", "nlp", "cv", "systems")
- Lessons = Topics within domain
- Items = Lessons, MCQ tests, short-answer exercises, coding exercises
- Progress synced with content from `content/mcq`, `content/short`, `docs/`

---

## Error Responses

| Status | Type | Title | When |
|--------|------|-------|------|
| 400 | `validation_error` | Invalid Request | Invalid payload, missing required fields |
| 401 | `unauthorized` | Unauthorized | Invalid/expired token |
| 403 | `forbidden` | Forbidden | No permission for resource/action |
| 404 | `not_found` | Not Found | Record/area/lesson not found |
| 409 | `conflict` | Conflict | Duplicate record (handled by upsert) |
| 500 | `internal_error` | Internal Server Error | Database error, unexpected failure |

---

## Permissions

| Endpoint | Required Permission |
|----------|---------------------|
| GET / | progress.read |
| GET /summary | progress.read |
| GET /:areaId/:lessonId | progress.read |
| GET /:recordId | progress.read |
| POST / | progress.write |
| PUT /:recordId | progress.write |
| DELETE /:recordId | progress.delete |

**Workshop**: Both admin and user have progress.read, progress.write, progress.delete
**ai_interviewing**: Admin has all; User has progress.read, progress.write (NO progress.delete)

---

## Deterministic Evidence Requirements

Every API call in tests must produce evidence:
1. Request/response captured (headers, body, status)
2. Database state delta verified (before/after)
3. JSON schema validation against contracts
4. Latency recorded (< 200ms p95)