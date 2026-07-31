# frozen_string_literal: true

FactoryBot.define do
  factory :expense do
    association :paid_by, factory: :user
    created_by { paid_by }
    title { "Dinner" }
    amount { "60.00" }
    currency { "USD" }
    split_type { "equal" }
    expense_date { Date.current }

    # expenseable (a Group or Friendship) must be supplied by the caller.
  end
end
