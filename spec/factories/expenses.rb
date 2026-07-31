# frozen_string_literal: true

FactoryBot.define do
  factory :expense do
    # Defaults to a friendship context; callers pass `expenseable:` for a
    # specific Group or Friendship.
    association :expenseable, factory: :friendship
    association :paid_by, factory: :user
    created_by { paid_by }
    title { "Dinner" }
    amount { "60.00" }
    currency { "USD" }
    split_type { "equal" }
    expense_date { Date.current }
  end
end
