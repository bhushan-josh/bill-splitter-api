# frozen_string_literal: true

FactoryBot.define do
  factory :expense_split do
    association :expense
    association :user
    amount { "10.00" }
    percentage { nil }
  end
end
