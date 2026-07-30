# Bill Splitter API

Production-ready Rails **API-only** backend for the Bill Splitter application.

## Tech stack

| Concern            | Choice                          |
| ------------------ | ------------------------------- |
| Language           | Ruby 3.2.0                      |
| Framework          | Rails 7.2.2.1 (API-only)        |
| Database           | PostgreSQL                      |
| Background jobs    | Sidekiq + Redis                 |
| Tests              | RSpec, FactoryBot, shoulda-matchers, DatabaseCleaner |
| Auth (deps only)   | JWT, bcrypt *(implemented later)* |
| Authorization      | Pundit                          |
| Pagination         | Pagy                            |
| CORS               | rack-cors                       |
| Config             | dotenv-rails                    |
| Linting            | RuboCop (+ rails/rspec/performance) |

## Prerequisites

- Ruby **3.2.0** (this repo pins it via `.ruby-version`)
- PostgreSQL running locally
- Redis running locally

## Setup

```bash
bundle install
cp .env.example .env      # then edit values as needed
bin/rails db:create
```

## Running

```bash
bin/rails server                       # API on http://localhost:3000
bundle exec sidekiq -C config/sidekiq.yml   # background worker
```

The Sidekiq dashboard is mounted at `/sidekiq` (lock it down before production).

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
bundle exec rspec
bundle exec rubocop
```

## Project structure

```
app/
  controllers/
    api/v1/           # versioned API controllers (BaseController, HealthController)
    concerns/         # JsonResponders (response envelope), ErrorHandler (rescue_from)
  services/           # business-action objects   (ApplicationService)
  queries/            # reusable AR query objects  (ApplicationQuery)
  policies/           # Pundit authorization       (ApplicationPolicy)
  serializers/        # response serialization      (ApplicationSerializer)
  presenters/         # view/response decoration    (ApplicationPresenter)
  jobs/               # Sidekiq/ActiveJob jobs
  concerns/           # shared app-wide concerns
```

### API conventions

All responses use a consistent JSON envelope:

- Success: `{ "success": true, "data": <payload>, "meta": <optional> }`
- Error: `{ "success": false, "error": { "message", "code", "details" } }`

Exceptions are handled centrally in `app/controllers/concerns/error_handler.rb`,
and unmatched routes fall through to a JSON `404` (see `config/routes.rb`).

> Authentication and business models are intentionally **not** implemented yet —
> only their dependencies (JWT, bcrypt) are configured.
