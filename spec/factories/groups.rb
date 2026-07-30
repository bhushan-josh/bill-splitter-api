# frozen_string_literal: true

FactoryBot.define do
  factory :group do
    sequence(:name) { |n| "Group #{n}" }
    description { "A shared expenses group" }
    image_url { Faker::Internet.url }
    association :owner, factory: :user

    # A group with the owner already registered as a member (mirrors what
    # GroupService.create does).
    trait :with_owner_membership do
      after(:create) do |group|
        create(:group_member, group: group, user: group.owner)
      end
    end
  end
end
