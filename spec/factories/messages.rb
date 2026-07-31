# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    # Defaults to a friend chat; callers pass `messageable:` for a Group.
    association :messageable, factory: :friendship
    association :sender, factory: :user
    body { "Hello there" }
  end
end
