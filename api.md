# REST API Specification (v1)

Base URL

```
/api/v1
```

---

# Authentication

```
POST /signup

POST /login

GET /me
```

---

# Users

```
GET /users/search
```

Query

```
?q=john
```

Searches by username or phone.

---

# Friend Requests

```
POST /friend_requests

PATCH /friend_requests/:id/accept

PATCH /friend_requests/:id/reject

DELETE /friend_requests/:id
```

---

# Friends

```
GET /friends

DELETE /friends/:id
```

---

# Groups

```
GET /groups

POST /groups

GET /groups/:id

PATCH /groups/:id

DELETE /groups/:id

POST /groups/:id/members

DELETE /groups/:id/members/:user_id

POST /groups/:id/leave

POST /groups/:id/transfer_owner
```

---

# Expenses

```
POST /expenses

GET /expenses/:id

PATCH /expenses/:id

DELETE /expenses/:id
```

Expense payload supports:

* Friend expense
* Group expense
* Equal split
* Percentage split
* Exact split

---

# Balances

```
GET /balances/friends

GET /balances/groups

GET /balances/overall
```

---

# Settlements

```
POST /settlements

PATCH /settlements/:id

DELETE /settlements/:id
```

---

# Messages

```
GET /messages

POST /messages
```

Supports both:

* Friendship conversations
* Group conversations

---

# Notifications

```
GET /notifications

PATCH /notifications/:id/read
```

---

# Activities

```
GET /groups/:id/activities
```

---

# Response Format

Success

```
{
  "success": true,
  "data": {}
}
```

Failure

```
{
  "success": false,
  "message": "Validation failed",
  "errors": []
}
```

---

# Versioning

All endpoints are namespaced under:

```
/api/v1
```

Future breaking changes should be introduced under `/api/v2` while keeping v1 backward compatible until clients migrate.
