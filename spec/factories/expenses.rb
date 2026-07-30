# frozen_string_literal: true

FactoryBot.define do
  factory :expense do
    association :expenseable, factory: :group
    title { "Dinner" }
    description { "Team dinner" }
    amount { "60.00" }
    currency { "USD" }
    split_type { "equal" }
    expense_date { Date.new(2026, 7, 30) }
    paid_by { expenseable.try(:owner) || association(:user) }
    created_by { expenseable.try(:owner) || association(:user) }
  end
end
