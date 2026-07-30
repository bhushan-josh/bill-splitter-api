# frozen_string_literal: true

require "rails_helper"

RSpec.describe FriendRequest, type: :model do
  it "has a valid factory" do
    expect(build(:friend_request)).to be_valid
  end

  describe "associations & status" do
    it { is_expected.to belong_to(:sender).class_name("User") }
    it { is_expected.to belong_to(:receiver).class_name("User") }

    it "defaults to pending" do
      expect(build(:friend_request).status).to eq("pending")
    end

    it "defines the expected statuses" do
      expect(described_class.statuses.keys).to contain_exactly("pending", "accepted", "rejected", "cancelled")
    end
  end

  describe "validations" do
    it "cannot be sent to yourself" do
      user = create(:user)
      request = build(:friend_request, sender: user, receiver: user)
      expect(request).not_to be_valid
      expect(request.errors[:receiver]).to include("cannot be yourself")
    end

    it "rejects a duplicate pending request (same direction)" do
      existing = create(:friend_request)
      dup = build(:friend_request, sender: existing.sender, receiver: existing.receiver)
      expect(dup).not_to be_valid
    end

    it "rejects a duplicate pending request (reverse direction)" do
      existing = create(:friend_request)
      reverse = build(:friend_request, sender: existing.receiver, receiver: existing.sender)
      expect(reverse).not_to be_valid
    end

    it "allows a new request after the previous one was rejected" do
      existing = create(:friend_request, status: "rejected")
      resend = build(:friend_request, sender: existing.sender, receiver: existing.receiver)
      expect(resend).to be_valid
    end
  end
end
