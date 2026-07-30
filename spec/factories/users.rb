# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    sequence(:username) { |n| "user_#{n}" }
    sequence(:phone) { |n| "+1#{format("%010d", n)}" }
    avatar_url { Faker::Internet.url }
    fcm_token { SecureRandom.hex(16) }
    password { "password123" }
  end
end
