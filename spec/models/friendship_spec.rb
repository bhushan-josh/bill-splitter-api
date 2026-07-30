# frozen_string_literal: true

require "rails_helper"

RSpec.describe Friendship, type: :model do
  it "has a valid factory" do
    expect(build(:friendship)).to be_valid
  end

  it { is_expected.to belong_to(:user).class_name("User") }
  it { is_expected.to belong_to(:friend).class_name("User") }

  it "cannot befriend yourself" do
    user = create(:user)
    friendship = build(:friendship, user: user, friend: user)
    expect(friendship).not_to be_valid
  end

  it "is unique per (user, friend) pair" do
    existing = create(:friendship)
    dup = build(:friendship, user: existing.user, friend: existing.friend)
    expect(dup).not_to be_valid
  end
end
