# Bill Splitter API — Reference

Complete reference for the Bill Splitter HTTP API: every endpoint with its
requirements, parameters, and response shapes.

- **Base URL:** `http://localhost:3000` (development)
- **Prefix:** all endpoints live under `/api/v1`
- **Content type:** `application/json` for request and response bodies

---

## Conventions

### Authentication

Every endpoint requires a JWT **except** `GET /health`, `POST /signup` and
`POST /login`. Obtain a token from signup/login and send it on every other
request:

```
Authorization: Bearer <token>
```

A missing or invalid token returns **401**:

```json
{ "success": false, "error": { "message": "You must be signed in to access this resource", "code": "unauthorized" } }
```

### Response envelope

**Success:**

```json
{ "success": true, "data": <payload>, "meta": <optional> }
```

**Error:**

```json
{ "success": false, "error": { "message": "…", "code": "…", "details": ["…"] } }
```

`code` and `details` are included only when present (`details` is typically an
array of validation messages).

### Pagination

List endpoints are paginated with query params:

| Param   | Default | Notes                          |
| ------- | ------- | ------------------------------ |
| `page`  | `1`     | Out-of-range clamps to last    |
| `limit` | `25`    | Max `100`                      |

Paginated responses include `meta.pagination`:

```json
"meta": { "pagination": { "page": 1, "limit": 25, "count": 42, "pages": 2, "next": 2, "prev": null } }
```

### Common error codes

| HTTP | `code`                | Meaning                                        |
| ---- | --------------------- | ---------------------------------------------- |
| 400  | `parameter_missing`   | A required parameter is missing                |
| 401  | `unauthorized`        | Missing / invalid token                        |
| 401  | `invalid_credentials` | Login failed                                   |
| 403  | `forbidden`           | Authenticated but not allowed                  |
| 404  | `not_found`           | Resource does not exist / not visible to you   |
| 409  | `invalid_transition`  | Friend-request state transition not allowed    |
| 422  | `record_invalid`      | Model validation failed (`details` lists them) |
| 422  | `invalid_expense`     | Expense rule violated                          |
| 422  | `invalid_settlement`  | Settlement rule violated                       |
| 422  | `invalid_action`      | Group rule violated                            |
| 422  | `invalid_message`     | Message rule violated                          |
| 500  | `internal_server_error` | Unexpected error                             |

### Shared object shapes

**User object** (returned wherever a user is embedded):

```json
{
  "id": 1,
  "name": "Ada Lovelace",
  "username": "ada",
  "phone": "+15551234567",
  "avatar_url": null,
  "fcm_token": null,
  "created_at": "2026-07-31T10:00:00Z",
  "updated_at": "2026-07-31T10:00:00Z"
}
```

Monetary values are returned as **fixed 2-decimal strings** (e.g. `"12.50"`) to
avoid float precision issues.

---

## Health

### `GET /api/v1/health`

Liveness/readiness check. **Public** (no auth).

**Response `200`:**

```json
{
  "success": true,
  "data": {
    "status": "ok",
    "service": "billsplitter-api",
    "version": "v1",
    "time": "2026-07-31T10:00:00Z",
    "dependencies": { "database": "ok", "redis": "ok" }
  }
}
```

`dependencies.*` is `"ok"` or `"unavailable"`.

---

## Authentication

### `POST /api/v1/signup`

Create an account and receive a JWT. **Public.**

**Body:**

| Field                   | Type   | Required | Notes                                              |
| ----------------------- | ------ | -------- | -------------------------------------------------- |
| `name`                  | string | yes      | ≤ 100 chars                                        |
| `username`              | string | yes      | 3–30 chars, `[a-zA-Z0-9_]`, unique (case-insensitive) |
| `phone`                 | string | yes      | `+?[0-9]{7,15}`, unique                             |
| `password`              | string | yes      | ≥ 6 chars                                          |
| `password_confirmation` | string | yes      | must match `password`                              |
| `avatar_url`            | string | no       | ≤ 2048 chars                                        |
| `fcm_token`             | string | no       | device token for push                              |

**Response `201`:**

```json
{ "success": true, "data": { "user": { …User }, "token": "<jwt>" } }
```

**Errors:** `422 record_invalid` (e.g. taken username/phone, weak password).

### `POST /api/v1/login`

Exchange credentials for a JWT. **Public.**

**Body:**

| Field      | Type   | Required | Notes                     |
| ---------- | ------ | -------- | ------------------------- |
| `login`    | string | yes      | username **or** phone     |
| `password` | string | yes      |                           |

**Response `200`:** same shape as signup (`{ user, token }`).

**Errors:** `401 invalid_credentials`.

### `GET /api/v1/me`

Return the authenticated user's profile.

**Response `200`:** `{ "success": true, "data": { …User } }`

---

## Users

### `GET /api/v1/users/search`

Search users by username or phone (partial, case-insensitive). Excludes the
current user. Paginated.

**Query:**

| Param   | Required | Notes                       |
| ------- | -------- | --------------------------- |
| `q`     | yes      | search term (username/phone)|
| `page`, `limit` | no | pagination                  |

**Response `200`:** `data` is an array of User objects, plus `meta.pagination`.

**Errors:** `400 parameter_missing` when `q` is blank.

---

## Friend Requests

A friend request is `pending` and can transition to `accepted`, `rejected`
(by the receiver) or `cancelled` (by the sender). Accepting creates a mutual
friendship.

**FriendRequest object:**

```json
{ "id": 5, "status": "pending", "sender": { …User }, "receiver": { …User }, "created_at": "…", "updated_at": "…" }
```

The **list** endpoint additionally tags each item with a `direction`
(`"incoming"` or `"outgoing"`) relative to the current user.

### `GET /api/v1/friend_requests`

List the current user's friend requests (both directions), newest first.
Paginated.

**Query:**

| Param       | Required | Default   | Notes                                                             |
| ----------- | -------- | --------- | ----------------------------------------------------------------- |
| `direction` | no       | `all`     | `incoming` \| `outgoing` \| `all`                                 |
| `status`    | no       | `pending` | `pending` \| `accepted` \| `rejected` \| `cancelled` \| `all`     |
| `page`, `limit` | no   |           | pagination                                                        |

**Response `200`:** array of FriendRequest objects (each with `direction`) +
`meta.pagination`.

**Errors:** `400 invalid_parameter` for an unknown `direction` or `status`.

### `POST /api/v1/friend_requests`

Send a request from the current user.

**Body:** `receiver_id` (integer, required).

**Response `201`:** the FriendRequest object.

**Errors:** `404 not_found` (unknown receiver); `422 record_invalid`
(self-request, or a pending request already exists between the pair).

### `PATCH /api/v1/friend_requests/:id/accept`

Receiver accepts. Creates the mutual friendship atomically.

**Response `200`:** the FriendRequest (`status: "accepted"`).

**Errors:** `404 not_found` (not the receiver / unknown); `409 invalid_transition`
(already non-pending).

### `PATCH /api/v1/friend_requests/:id/reject`

Receiver rejects. Same responses/errors as accept (`status: "rejected"`).

### `DELETE /api/v1/friend_requests/:id`

Sender cancels their own pending request.

**Response `200`:** the FriendRequest (`status: "cancelled"`).

**Errors:** `404 not_found` (not the sender / unknown); `409 invalid_transition`.

---

## Friends

### `GET /api/v1/friends`

List the current user's friends, newest first. Paginated.

**Response `200`:** array of **friend** objects (a User object plus
`friends_since`), with `meta.pagination`:

```json
{ …User, "friends_since": "2026-07-31T10:00:00Z" }
```

### `DELETE /api/v1/friends/:id`

Unfriend. `:id` is the **friend's user id**. Removes both directed friendship
rows and cascades to that friendship's expenses, splits, settlements and
messages.

**Response `200`:** `{ "success": true, "data": { "removed_friend_id": 7 } }`

**Errors:** `404 not_found` when the target is not a friend.

---

## Expenses

An expense belongs to a **context** — either a `friend` (a friendship) or a
`group` — and is split among participants three ways:

- `equal` — divided evenly, leftover cents spread across the first participants
- `percentage` — participant `percentage`s must total `100`
- `exact` — participant `amount`s must total the expense `amount`

Only the **creator** may update or delete an expense. A viewer must be a member
of the context.

**Expense object:**

```json
{
  "id": 10,
  "title": "Dinner",
  "description": null,
  "amount": "60.00",
  "currency": "USD",
  "split_type": "equal",
  "expense_date": "2026-07-31",
  "context": { "type": "Group", "id": 3 },
  "paid_by": { …User },
  "created_by": { …User },
  "splits": [ { "user": { …User }, "amount": "30.00", "percentage": null } ],
  "created_at": "…",
  "updated_at": "…"
}
```

### `POST /api/v1/expenses`

Create an expense.

**Body:**

| Field          | Type    | Required | Notes                                                      |
| -------------- | ------- | -------- | ---------------------------------------------------------- |
| `context_type` | string  | yes      | `"group"` or `"friend"`                                    |
| `group_id`     | integer | if group | the group (actor must be an active member)                 |
| `friend_id`    | integer | if friend| the friend (must be an accepted friend)                    |
| `title`        | string  | yes      | ≤ 200 chars                                                |
| `description`  | string  | no       | ≤ 2000 chars                                               |
| `amount`       | number  | yes      | > 0                                                        |
| `currency`     | string  | no       | 3-letter code, default `"USD"`                             |
| `paid_by_id`   | integer | no       | defaults to creator; must be a participant of the context |
| `split_type`   | string  | yes      | `equal` \| `percentage` \| `exact`                         |
| `expense_date` | date    | yes      | `YYYY-MM-DD`                                               |
| `participants` | array   | yes      | ≥ 1 entry; each `{ user_id, amount?, percentage? }`        |

Participant rules by `split_type`: `equal` needs only `user_id`; `percentage`
needs `percentage` (summing to 100); `exact` needs `amount` (summing to the
total). Participants must be unique and belong to the context.

**Response `201`:** the Expense object.

**Errors:** `403 forbidden` (not a member of the group); `422 invalid_expense`
(bad context, non-participant payer, split totals don't reconcile, duplicate or
out-of-context participants, invalid numbers); `404 not_found`.

### `GET /api/v1/expenses/:id`

Fetch an expense. Requires the caller to be a member of its context.

**Response `200`:** the Expense object.

**Errors:** `403 forbidden` (no access); `404 not_found`.

### `PATCH /api/v1/expenses/:id`

Update an expense — **creator only**. Any subset of the create fields may be
sent. Splits are rebuilt when `participants`, `amount` or `split_type` change
(and `paid_by_id` may be reassigned).

**Response `200`:** the updated Expense object.

**Errors:** `403 forbidden` (not the creator); `422 invalid_expense`; `404 not_found`.

### `DELETE /api/v1/expenses/:id`

Delete an expense (and its splits) — **creator only**.

**Response `200`:** `{ "success": true, "data": { "deleted_expense_id": 10 } }`

**Errors:** `403 forbidden`; `404 not_found`.

---

## Settlements

A settlement is a payment `from_user → to_user` that pays down debt, scoped to a
`friend` or `group` context. Both parties must belong to the context and be
distinct. Only the **creator** may update or delete.

**Settlement object:**

```json
{
  "id": 20,
  "context_type": "group",
  "group": { "id": 3, "name": "Trip" },
  "from_user": { …User },
  "to_user": { …User },
  "amount": "25.00",
  "note": "cash",
  "created_at": "…",
  "updated_at": "…"
}
```

`context_type` is `"group"` or `"friend"`; `group` is `null` for friend
settlements.

### `POST /api/v1/settlements`

**Body:**

| Field          | Type    | Required | Notes                                       |
| -------------- | ------- | -------- | ------------------------------------------- |
| `context_type` | string  | yes      | `"group"` or `"friend"`                     |
| `group_id`     | integer | if group | actor must be an active member              |
| `friend_id`    | integer | if friend| must be an accepted friend                  |
| `from_user_id` | integer | yes      | payer; must belong to the context           |
| `to_user_id`   | integer | yes      | payee; must belong to the context, ≠ payer  |
| `amount`       | number  | yes      | > 0                                         |
| `note`         | string  | no       | ≤ 2000 chars                                |

**Response `201`:** the Settlement object.

**Errors:** `403 forbidden` (not a group member); `422 invalid_settlement`
(missing/invalid parties, parties outside context, equal parties, invalid
amount); `404 not_found`.

### `PATCH /api/v1/settlements/:id`

Update — **creator only**. Any subset of `amount`, `note`, `from_user_id`,
`to_user_id`.

**Response `200`:** the updated Settlement.

**Errors:** `403 forbidden`; `422 invalid_settlement`; `404 not_found`.

### `DELETE /api/v1/settlements/:id`

Delete — **creator only**.

**Response `200`:** `{ "success": true, "data": { "deleted_settlement_id": 20 } }`

---

## Balances

Balances are **derived on demand** from expense splits and settlements. Sign
convention (from the current user's perspective): a positive `net_balance` means
the counterparty **owes you**; negative means **you owe** them. All figures are
2-decimal strings.

### `GET /api/v1/balances/friends`

Per-friend balances plus a rolled-up summary.

**Response `200`:**

```json
{
  "success": true,
  "data": {
    "summary": { "owed": "40.00", "owes": "10.00", "net_balance": "30.00" },
    "friends": [
      { "user": { …User }, "owed": "30.00", "owes": "0.00", "net_balance": "30.00" }
    ]
  }
}
```

### `GET /api/v1/balances/groups`

Per-group balances, each with its per-member breakdown, plus a summary.

**Response `200`:**

```json
{
  "success": true,
  "data": {
    "summary": { "owed": "…", "owes": "…", "net_balance": "…" },
    "groups": [
      {
        "group": { "id": 3, "name": "Trip", "image_url": null },
        "owed": "…", "owes": "…", "net_balance": "…",
        "members": [ { "user": { …User }, "owed": "…", "owes": "…", "net_balance": "…" } ]
      }
    ]
  }
}
```

### `GET /api/v1/balances/overall`

Aggregate position across friends and groups.

**Response `200`:** `{ "success": true, "data": { "owed": "…", "owes": "…", "net_balance": "…" } }`

---

## Messages

Text chat scoped to a `friend` or `group` context.

- Friend chat requires an accepted friendship between the two users.
- Group chat requires the sender to be an active member.

**Message object:**

```json
{ "id": 30, "body": "hi", "sender": { …User }, "created_at": "…", "updated_at": "…" }
```

### `GET /api/v1/messages`

List messages for a context, newest first. Paginated.

**Query:**

| Param          | Required | Notes                          |
| -------------- | -------- | ------------------------------ |
| `context_type` | yes      | `"group"` or `"friend"`        |
| `group_id`     | if group |                                |
| `friend_id`    | if friend|                                |
| `page`, `limit`| no       | pagination                     |

**Response `200`:** array of Message objects + `meta.pagination`.

**Errors:** `403 forbidden` (not a group member); `422 invalid_message`
(bad context, not friends); `404 not_found`.

### `POST /api/v1/messages`

Send a message.

**Body:** `context_type` (+ `group_id`/`friend_id`) as above, plus `body`
(string, required, ≤ 5000 chars).

**Response `201`:** the Message object.

**Errors:** as for the list endpoint, plus `422 invalid_message` on a blank body.

---

## Notifications

In-app notifications for the current user. `type` is one of `friend_request`,
`expense`, `settlement`, `group_added`; `data` carries ids for deep-linking.

**Notification object:**

```json
{
  "id": 40,
  "type": "expense",
  "title": "New expense",
  "body": "Ada added \"Dinner\"",
  "data": { "expense_id": 10, "amount": "60.00" },
  "read_at": null,
  "created_at": "…"
}
```

### `GET /api/v1/notifications`

List the current user's notifications, newest first. Paginated.

**Response `200`:** array of Notification objects + `meta.pagination`.

### `PATCH /api/v1/notifications/:id/read`

Mark a notification as read (idempotent — keeps the original timestamp if
already read).

**Response `200`:** the Notification object (with `read_at` set).

**Errors:** `404 not_found` (not the owner / unknown).

---

## Groups

A group is owned by one user and has members (join rows with soft-leave via
`left_at`). **Owner-only** actions: update, delete, add/remove member, transfer
ownership. Deleting a group cascades to its expenses, splits, settlements,
messages and activity.

**Group object:**

```json
{
  "id": 3,
  "name": "Trip",
  "description": "Goa",
  "image_url": null,
  "owner": { …User },
  "members_count": 2,
  "created_at": "…",
  "updated_at": "…",
  "members": [ { …User } ]
}
```

`members` is included on single-group responses (`show`, `create`, membership
actions); it is omitted from the `index` list.

### `GET /api/v1/groups`

List groups the current user is an active member of, newest first. Paginated.

**Response `200`:** array of Group objects (without `members`) + `meta.pagination`.

### `POST /api/v1/groups`

Create a group; the creator becomes owner and first member.

**Body:** `name` (required, ≤ 150), `description` (≤ 2000), `image_url` (≤ 2048).

**Response `201`:** the Group object (with `members`).

**Errors:** `422 record_invalid`.

### `GET /api/v1/groups/:id`

Fetch a group — **members only**.

**Response `200`:** the Group object (with `members`).

**Errors:** `403 forbidden` (not a member).

### `PATCH /api/v1/groups/:id`

Update — **owner only**. Body: `name`, `description`, `image_url`.

**Response `200`:** the Group object.

**Errors:** `403 forbidden`; `422 record_invalid`.

### `DELETE /api/v1/groups/:id`

Delete — **owner only**.

**Response `200`:** `{ "success": true, "data": { "deleted_group_id": 3 } }`

**Errors:** `403 forbidden`.

### `POST /api/v1/groups/:id/members`

Add a member — **owner only**. The user must be one of the owner's friends.
Re-adds a previously departed member.

**Body:** `user_id` (integer, required).

**Response `201`:** the Group object (with updated `members`).

**Errors:** `403 forbidden` (not owner); `422 invalid_action` (not a friend, or
already an active member); `404 not_found`.

### `DELETE /api/v1/groups/:id/members/:user_id`

Remove a member (soft-leave) — **owner only**. The owner cannot be removed this
way.

**Response `200`:** the Group object.

**Errors:** `403 forbidden`; `422 invalid_action` (target is the owner, or not an
active member); `404 not_found`.

### `POST /api/v1/groups/:id/leave`

The current user leaves the group. The owner must transfer ownership first.

**Response `200`:** `{ "success": true, "data": { "left_group_id": 3 } }`

**Errors:** `422 invalid_action` (owner must transfer first, or not an active
member).

### `POST /api/v1/groups/:id/transfer_owner`

Transfer ownership — **owner only** — to another active member.

**Body:** `new_owner_id` (integer, required).

**Response `200`:** the Group object (with the new owner).

**Errors:** `403 forbidden`; `422 invalid_action` (new owner is not an active
member); `404 not_found`.

---

## Activities

Each group has an append-only activity timeline (group/member/expense/settlement
events).

**Activity object:**

```json
{
  "id": 50,
  "action": "expense_created",
  "actor": { …User },
  "trackable": { "type": "Expense", "id": 10 },
  "metadata": { "expense_id": 10, "title": "Dinner", "amount": "60.00" },
  "created_at": "…"
}
```

`trackable` is `null` when the referenced record no longer exists (e.g. a
deleted expense); `metadata` preserves the human-readable details. `action` is
one of: `group_created`, `group_renamed`, `member_joined`, `member_removed`,
`expense_created`, `expense_updated`, `expense_deleted`, `settlement_created`.

### `GET /api/v1/groups/:group_id/activities`

List a group's timeline, newest first — **members only**. Paginated.

**Response `200`:** array of Activity objects + `meta.pagination`.

**Errors:** `403 forbidden` (not a member); `404 not_found` (unknown group).

---

## Notes

- **Times** are ISO 8601 UTC (e.g. `2026-07-31T10:00:00Z`); **dates** are
  `YYYY-MM-DD`.
- **Money** is always a 2-decimal string.
- Unmatched routes return a JSON `404` in the standard error envelope.
