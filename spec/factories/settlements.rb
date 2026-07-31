# frozen_string_literal: true

FactoryBot.define do
  factory :settlement do
    association :from_user, factory: :user
    association :to_user, factory: :user
    created_by { from_user }
    amount { "10.00" }
    note { nil }

    # settleable (a Group or Friendship) must be supplied by the caller.
  end
end
