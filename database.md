# Database Design

## Users

```
id
name
username
phone
password_digest
avatar_url
fcm_token
timestamps
```

---

## Friend Requests

```
id
sender_id
receiver_id
status

pending
accepted
rejected
cancelled

timestamps
```

---

## Friendships

Two rows are stored.

```
A → B

B → A
```

Fields

```
id
user_id
friend_id
timestamps
```

---

## Groups

```
id
name
description
owner_id
image_url
timestamps
```

---

## Group Members

```
id
group_id
user_id
left_at
timestamps
```

---

## Expenses

Expense belongs to Friendship or Group.

```
id

expenseable_type
expenseable_id

paid_by_id
created_by_id

title
description

amount
currency

split_type

expense_date

timestamps
```

Split Types

* equal
* percentage
* exact

---

## Expense Splits

```
id

expense_id

user_id

amount

percentage

timestamps
```

---

## Settlements

Settlement belongs to Friendship or Group.

```
id

settleable_type
settleable_id

from_user_id

to_user_id

created_by_id

amount

note

timestamps
```

---

## Messages

```
id

messageable_type
messageable_id

sender_id

content

timestamps
```

---

## Notifications

```
id

user_id

title

body

notification_type

data (jsonb)

read_at

timestamps
```

---

## Activities

```
id

group_id

actor_id

action

trackable_type
trackable_id

metadata (jsonb)

timestamps
```

---

# Relationships

User

* has_many friendships
* has_many group_members
* has_many groups (owned)
* has_many expenses (created)
* has_many expense_splits
* has_many notifications

Friendship

* belongs_to user
* belongs_to friend
* has_many expenses
* has_many messages

Group

* belongs_to owner
* has_many group_members
* has_many members
* has_many expenses
* has_many messages
* has_many activities

Expense

* belongs_to expenseable
* belongs_to paid_by
* belongs_to created_by
* has_many expense_splits

Settlement

* belongs_to settleable

Message

* belongs_to messageable

Notification

* belongs_to user

Activity

* belongs_to group
* belongs_to actor

---

# Important Rules

* User cannot friend themselves.
* Username is unique.
* Phone number is unique.
* Only accepted friends can create private expenses.
* Only group members can create group expenses.
* Expense split total must equal expense amount.
* Percentage split total must equal 100.
* Only expense creator can edit/delete an expense.
* Group owner cannot leave before transferring ownership.
* All balance calculations are derived from ExpenseSplits and Settlements.

