# Bill Splitter API - Architecture

## Overview

Bill Splitter is a RESTful backend API that allows users to split expenses with friends and groups, settle debts, exchange messages, and receive notifications.

The backend is built using Ruby on Rails 7.2.2.1 as an API-only application following service-oriented architecture with thin controllers and business logic extracted into service objects.

---

# Technology Stack

* Ruby 3.2.0
* Rails 7.2.2.1 (API Only)
* PostgreSQL
* Redis
* Sidekiq
* JWT Authentication
* bcrypt
* RSpec
* FactoryBot
* Shoulda Matchers
* Faker
* Pundit
* Pagy

---

# Architecture Principles

## Thin Controllers

Controllers should only:

* Authenticate requests
* Validate parameters
* Call services
* Render JSON responses

No business logic belongs in controllers.

---

## Service Objects

Business logic belongs inside services.

Example:

```
app/services/

auth/
friend_requests/
friendships/
groups/
expenses/
settlements/
balances/
notifications/
activities/
messages/
```

---

## Transactions

Use database transactions whenever multiple records are created or updated.

Examples:

* Accept Friend Request
* Create Expense
* Update Expense
* Delete Expense
* Create Settlement
* Transfer Group Ownership

---

## Authorization

Pundit will be used for authorization.

Examples:

* Only owner can update group.
* Only expense creator can edit/delete an expense.
* Only group members can access group resources.
* Only friends can create private expenses.

---

## Error Handling

All APIs return consistent JSON.

Success

```
{
  "success": true,
  "data": {}
}
```

Error

```
{
  "success": false,
  "message": "Validation failed",
  "errors": []
}
```

---

## Background Jobs

Sidekiq will handle:

* Push notifications
* Future reminders
* Future recurring expenses

---

## Folder Structure

```
app/

controllers/
  api/v1/

models/

services/

queries/

policies/

serializers/

jobs/

validators/

concerns/
```

---

# Core Modules

Authentication

* Signup
* Login
* JWT
* Current User

Friend System

* Search users
* Friend Requests
* Friendships

Groups

* Create
* Update
* Delete
* Add Members
* Remove Members
* Leave Group
* Transfer Ownership

Expenses

* Friend Expense
* Group Expense
* Equal Split
* Percentage Split
* Exact Split

Balances

* Friend Balance
* Group Balance
* Overall Balance

Settlements

* Friend Settlement
* Group Settlement

Messaging

* Friend Chat
* Group Chat

Notifications

* In-App
* Push (FCM)

Activity Timeline

* Group Activities

---

# Design Decisions

* Two friendship records are stored after acceptance.
* Expense belongs to either Friendship or Group using polymorphic associations.
* Messages belong to Friendship or Group using polymorphic associations.
* Balances are calculated dynamically.
* No balance table is stored.
* Expense history is immutable except explicit edit/delete actions.
* Notifications are asynchronous where possible.
* Every important action creates an Activity record.

---

# Future Roadmap

Version 2

* Receipt uploads
* Debt simplification
* Recurring expenses
* Image/File chat
* Read receipts
* Typing indicators
* Multi-currency
* Export PDF/CSV
* Group invite links
* Expense reminders

