# frozen_string_literal: true

FactoryBot.define do
  factory :group_member do
    association :group, factory: :group
    association :user, factory: :user
    left_at { nil }

    trait :departed do
      left_at { Time.current }
    end
  end
end
