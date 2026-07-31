# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    association :user, factory: :user
    title { "New friend request" }
    body { "Someone sent you a friend request" }
    notification_type { "friend_request" }
    data { {} }
  end
end
