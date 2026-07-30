# frozen_string_literal: true

FactoryBot.define do
  factory :friend_request do
    association :sender, factory: :user
    association :receiver, factory: :user
    status { "pending" }
  end
end
