# Bill Splitter API

Production-ready Rails **API-only** backend for the Bill Splitter application —
a Splitwise-style service for tracking shared expenses, settling debts and
chatting, across both **friends** and **groups**.

Balances are **derived on demand** from expense splits and settlements; nothing
is precomputed or cached, so every figure is always consistent with the
underlying records.

## Tech stack

| Concern            | Choice                                               |
| ------------------ | ---------------------------------------------------- |
| Language           | Ruby 3.2.0                                            |
| Framework          | Rails 7.2.2.1 (API-only)                              |
| Database           | PostgreSQL                                            |
| Background jobs    | Sidekiq + Redis                                       |
| Authentication     | JWT (Bearer tokens) + bcrypt (`has_secure_password`) |
| Authorization      | Enforced in service objects; Pundit wired in         |
| Pagination         | Pagy                                                  |
| Push notifications | FCM (via `FcmPushJob`)                                |
| Tests              | RSpec, FactoryBot, shoulda-matchers, DatabaseCleaner |
| CORS               | rack-cors                                             |
| Config             | dotenv-rails                                          |
| Linting            | RuboCop (+ rails / rspec / performance)               |

## Features

- **Auth** — signup / login issuing JWTs; every other endpoint requires a valid
  `Authorization: Bearer <token>` header.
- **Friends** — friend requests (send / accept / reject / cancel) and mutual
  friendships (stored as two directed rows, always created/removed atomically).
- **Groups** — create, rename, delete; owner-only membership management
  (add friends, remove members, soft-leave) and ownership transfer; per-group
  activity timeline.
- **Expenses** — friend or group expenses split three ways (`equal`,
  `percentage`, `exact`); split totals are validated to reconcile with the
  amount to the cent.
- **Settlements** — payments that pay down debt; feed directly into balances.
- **Balances** — per-friend, per-group and overall net positions, computed
  with a fixed set of aggregate queries (no N+1, independent of data volume).
- **Chat** — text messages in friend or group conversations.
- **Notifications** — in-app notifications with read tracking, plus FCM push
  delivery via a background job.

## Domain model

| Model           | Notes                                                                           |
| --------------- | ------------------------------------------------------------------------------- |
| `User`          | `has_secure_password`; unique `username` / `phone`; login by either.            |
| `FriendRequest` | State machine (`pending → accepted / rejected / cancelled`).                     |
| `Friendship`    | Directed edge (A→B); a mutual friendship is two rows.                            |
| `Group`         | Owned by a `User`; members via `GroupMember` (soft-leave with `left_at`).       |
| `GroupMember`   | Join row; `active` scope = `left_at IS NULL`.                                    |
| `Expense`       | Polymorphic `expenseable` (Group **or** Friendship); `has_many :expense_splits`.|
| `ExpenseSplit`  | Per-participant share; unique per `(expense, user)`.                             |
| `Settlement`    | Polymorphic `settleable`; a payment `from_user → to_user`.                       |
| `Message`       | Polymorphic `messageable` (Group or Friendship); text only.                     |
| `Notification`  | Per-user; `notification_type` + JSON `data` for deep-linking.                    |
| `Activity`      | Per-group timeline entry (`actor`, `action`, polymorphic `trackable`).          |

## Architecture

Controllers stay thin; all business logic and authorization live in PORO
service objects, wrapped in transactions where multiple writes must stay
consistent.

```
app/
  controllers/
    api/v1/           # versioned, thin API controllers
    concerns/         # Authentication, CurrentUser, JsonResponders, ErrorHandler
  services/           # business actions & rules (ExpenseService, GroupService, …)
  serializers/        # PORO response serializers (ApplicationSerializer)
  policies/           # Pundit authorization       (ApplicationPolicy)
  queries/            # reusable AR query objects   (ApplicationQuery)
  presenters/         # response decoration         (ApplicationPresenter)
  jobs/               # Sidekiq / ActiveJob jobs    (FcmPushJob)
  models/             # AR models, validations, associations
```

Key services: `ExpenseService`, `SettlementService`, `SplitCalculator`,
`BalanceCalculator`, `GroupService`, `FriendshipService`, `FriendRequestService`,
`MessageService`, `NotificationService`, `ActivityService`, `JwtService`.

### API conventions

All responses use a consistent JSON envelope:

- **Success:** `{ "success": true, "data": <payload>, "meta": <optional> }`
- **Error:** `{ "success": false, "error": { "message", "code", "details" } }`

Paginated collections include `meta.pagination` (`page`, `limit`, `count`,
`pages`, `next`, `prev`).

Exceptions are handled centrally in
`app/controllers/concerns/error_handler.rb`, and unmatched routes fall through
to a JSON `404` (see `config/routes.rb`). Common error codes: `unauthorized`,
`forbidden`, `not_found`, `record_invalid`, `parameter_missing`,
`invalid_expense`, `invalid_settlement`, `invalid_action`,
`invalid_transition`, `invalid_credentials`.

### Data integrity

- Every real foreign key column has a database FK and a covering index.
- Uniqueness is enforced at the DB level (unique indexes) **and** the model
  (e.g. `username`, `phone`, `(expense, user)`, pending friend-request pairs via
  a partial unique index).
- Polymorphic columns (`expenseable`, `settleable`, `messageable`) cannot carry
  a DB foreign key, so `Group` and `Friendship` own their polymorphic children
  with `dependent: :destroy` — deleting a group (or unfriending) cascades to its
  expenses, splits, settlements and messages, leaving no orphaned rows.

## Authentication

```bash
# Sign up (returns a JWT)
curl -X POST http://localhost:3000/api/v1/signup \
  -H 'Content-Type: application/json' \
  -d '{"name":"Ada","username":"ada","phone":"+15551234567","password":"secret1","password_confirmation":"secret1"}'

# Log in (login = username or phone)
curl -X POST http://localhost:3000/api/v1/login \
  -H 'Content-Type: application/json' \
  -d '{"login":"ada","password":"secret1"}'

# Use the token on every other request
curl http://localhost:3000/api/v1/me \
  -H 'Authorization: Bearer <token>'
```

## API reference

Full endpoint documentation — parameters, requirements and response shapes for
every route — lives in **[docs/API.md](docs/API.md)**. Quick index below.

All routes are prefixed with `/api/v1`. Everything except `health`, `signup`
and `login` requires a Bearer token.

| Method & path                                  | Description                             |
| ---------------------------------------------- | --------------------------------------- |
| `GET  /health`                                 | Liveness + dependency (DB/Redis) check  |
| `POST /signup` · `POST /login`                 | Create account / obtain a JWT           |
| `GET  /me`                                      | Current user's profile                  |
| `GET  /users/search?q=`                         | Search users by username or phone       |
| `POST /friend_requests`                         | Send a friend request                   |
| `PATCH /friend_requests/:id/accept` · `/reject` | Receiver accepts / rejects              |
| `DELETE /friend_requests/:id`                   | Sender cancels                          |
| `GET  /friends` · `DELETE /friends/:id`         | List friends / unfriend                 |
| `POST /expenses` · `GET/PATCH/DELETE /expenses/:id` | Manage expenses (creator-only edits)|
| `POST /settlements` · `PATCH/DELETE /settlements/:id` | Manage settlements (creator-only)  |
| `GET  /messages` · `POST /messages`             | List / send chat messages               |
| `GET  /notifications` · `PATCH /notifications/:id/read` | List / mark read                 |
| `GET  /balances/friends` · `/groups` · `/overall` | Derived balances                      |
| `GET/POST /groups` · `GET/PATCH/DELETE /groups/:id` | Manage groups                       |
| `POST /groups/:id/members` · `DELETE /groups/:id/members/:user_id` | Owner membership mgmt |
| `POST /groups/:id/leave` · `/transfer_owner`    | Leave / transfer ownership              |
| `GET  /groups/:group_id/activities`             | Group activity timeline (members only)  |

Expenses and settlements are scoped by a `context_type` of `"friend"`
(with `friend_id`) or `"group"` (with `group_id`).

## Prerequisites

- Ruby **3.2.0** (pinned via `.ruby-version`)
- PostgreSQL running locally
- Redis running locally

## Setup

```bash
bundle install
cp .env.example .env      # then edit values as needed
bin/rails db:prepare      # create + load schema (or db:create db:migrate)
```

## Running

```bash
bin/rails server                              # API on http://localhost:3000
bundle exec sidekiq -C config/sidekiq.yml     # background worker
```

### Configuration (environment)

Configured via `.env` (see `.env.example`):

| Variable                                     | Purpose                                            |
| -------------------------------------------- | -------------------------------------------------- |
| `DATABASE_*`, `RAILS_MAX_THREADS`            | PostgreSQL connection                              |
| `REDIS_URL`, `SIDEKIQ_CONCURRENCY`           | Redis / Sidekiq                                    |
| `CORS_ORIGINS`                               | Comma-separated allowed origins (`*` = dev only)   |
| `JWT_SECRET_KEY`                             | Signs/verifies JWTs (falls back to `secret_key_base`) |
| `SIDEKIQ_WEB_USERNAME`, `SIDEKIQ_WEB_PASSWORD` | HTTP Basic credentials for the Sidekiq dashboard |

### Sidekiq dashboard

Mounted at `/sidekiq` and protected by HTTP Basic auth (see
`config/initializers/sidekiq_web.rb`):

- With `SIDEKIQ_WEB_USERNAME` **and** `SIDEKIQ_WEB_PASSWORD` set, those
  credentials are required (constant-time comparison).
- When unset, the dashboard is open in development/test but **locked down in
  production** — an unconfigured production deploy never exposes it.

## Health check

```bash
curl http://localhost:3000/api/v1/health
```

```json
{
  "success": true,
  "data": {
    "status": "ok",
    "service": "billsplitter-api",
    "version": "v1",
    "time": "2026-07-30T10:00:00Z",
    "dependencies": { "database": "ok", "redis": "ok" }
  }
}
```

## Tests & linting

```bash
bundle exec rspec       # request, model & service specs
bundle exec rubocop     # style / lint
```

The suite covers request, model and service layers (**256 examples**), including
N+1 guards and polymorphic cascade behavior. RuboCop runs clean.
