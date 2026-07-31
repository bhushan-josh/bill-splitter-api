# frozen_string_literal: true

require "rails_helper"

RSpec.describe MessageService do
  subject(:service) { described_class.new }

  let(:me) { create(:user) }
  let(:alice) { create(:user) }
  let(:bob) { create(:user) }

  def group_with_members(*users, owner:)
    group = create(:group, owner: owner)
    ([owner] + users).uniq.each { |user| create(:group_member, group: group, user: user) }
    group
  end

  describe "#create" do
    context "with a friend chat" do
      before { FriendshipService.new.befriend(me, alice) }

      it "posts a message anchored to the canonical friendship row", :aggregate_failures do
        message = service.create(sender: me, params: { context_type: "friend", friend_id: alice.id, body: "hi" })

        expect(message).to be_persisted
        expect(message.sender).to eq(me)
        expect(message.body).to eq("hi")
        expect(message.messageable_type).to eq("Friendship")
        low, high = [me.id, alice.id].minmax
        expect([message.messageable.user_id, message.messageable.friend_id]).to eq([low, high])
      end

      it "rejects a blank body" do
        expect do
          service.create(sender: me, params: { context_type: "friend", friend_id: alice.id, body: " " })
        end.to raise_error(MessageService::InvalidMessage, /Body/)
      end

      it "rejects messaging a non-friend" do
        expect do
          service.create(sender: me, params: { context_type: "friend", friend_id: bob.id, body: "hi" })
        end.to raise_error(MessageService::InvalidMessage, /accepted friends/)
      end
    end

    context "with a group chat" do
      let(:group) { group_with_members(alice, owner: me) }

      it "posts a message to the group" do
        message = service.create(sender: me, params: { context_type: "group", group_id: group.id, body: "gm" })

        expect(message).to be_persisted
        expect(message.messageable).to eq(group)
      end

      it "forbids a non-member from posting" do
        stranger = create(:user)
        expect do
          service.create(sender: stranger, params: { context_type: "group", group_id: group.id, body: "gm" })
        end.to raise_error(MessageService::NotAuthorized, /not a member/)
      end
    end

    it "rejects an unknown context type" do
      expect do
        service.create(sender: me, params: { context_type: "planet", body: "hi" })
      end.to raise_error(MessageService::InvalidMessage, /context_type/)
    end
  end

  describe "#messages_for" do
    context "with a friend chat" do
      before { FriendshipService.new.befriend(me, alice) }

      it "returns the same conversation to both participants regardless of who queries" do
        service.create(sender: me, params: { context_type: "friend", friend_id: alice.id, body: "from me" })
        service.create(sender: alice, params: { context_type: "friend", friend_id: me.id, body: "from alice" })

        mine = service.messages_for(user: me, params: { context_type: "friend", friend_id: alice.id })
        theirs = service.messages_for(user: alice, params: { context_type: "friend", friend_id: me.id })

        expect(mine.pluck(:body)).to contain_exactly("from me", "from alice")
        expect(theirs.pluck(:body)).to contain_exactly("from me", "from alice")
      end

      it "orders newest first" do
        older = service.create(sender: me, params: { context_type: "friend", friend_id: alice.id, body: "first" })
        newer = service.create(sender: me, params: { context_type: "friend", friend_id: alice.id, body: "second" })

        result = service.messages_for(user: me, params: { context_type: "friend", friend_id: alice.id })
        expect(result.map(&:id)).to eq([newer.id, older.id])
      end
    end

    it "forbids a non-member from reading a group chat" do
      group = group_with_members(alice, owner: me)
      stranger = create(:user)
      expect do
        service.messages_for(user: stranger, params: { context_type: "group", group_id: group.id })
      end.to raise_error(MessageService::NotAuthorized)
    end
  end
end
