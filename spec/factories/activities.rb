# frozen_string_literal: true

FactoryBot.define do
  factory :activity do
    association :group, factory: :group
    association :actor, factory: :user
    action { "group_created" }
    trackable { group }
    metadata { {} }
  end
end
