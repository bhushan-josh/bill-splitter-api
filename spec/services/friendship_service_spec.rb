# frozen_string_literal: true

require "rails_helper"

RSpec.describe FriendshipService do
  let(:alice) { create(:user) }
  let(:bob) { create(:user) }

  describe "#befriend" do
    it "creates two directed rows (A -> B and B -> A)" do
      expect { described_class.new.befriend(alice, bob) }.to change(Friendship, :count).by(2)

      expect(Friendship.exists?(user: alice, friend: bob)).to be(true)
      expect(Friendship.exists?(user: bob, friend: alice)).to be(true)
    end

    it "makes the users mutual friends" do
      described_class.new.befriend(alice, bob)
      expect(alice.reload.friends).to include(bob)
      expect(bob.reload.friends).to include(alice)
    end

    it "is idempotent" do
      described_class.new.befriend(alice, bob)
      expect { described_class.new.befriend(alice, bob) }.not_to change(Friendship, :count)
    end
  end

  describe "#unfriend" do
    before { described_class.new.befriend(alice, bob) }

    it "removes both directed rows" do
      expect { described_class.new.unfriend(alice, bob) }.to change(Friendship, :count).by(-2)
      expect(alice.reload.friends).to be_empty
      expect(bob.reload.friends).to be_empty
    end

    it "works regardless of argument order" do
      expect { described_class.new.unfriend(bob, alice) }.to change(Friendship, :count).by(-2)
    end
  end
end
