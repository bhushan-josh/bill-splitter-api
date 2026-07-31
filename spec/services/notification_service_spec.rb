# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationService do
  subject(:service) { described_class.new }

  let(:me) { create(:user) }
  let(:alice) { create(:user) }
  let(:bob) { create(:user) }

  describe "#friend_request_received" do
    it "notifies the receiver and enqueues a push", :aggregate_failures do
      friend_request = create(:friend_request, sender: alice, receiver: me)

      expect { service.friend_request_received(friend_request) }
        .to change { me.notifications.count }.by(1)
        .and have_enqueued_job(FcmPushJob)

      notification = me.notifications.last
      expect(notification.notification_type).to eq("friend_request")
      expect(notification.data["sender_id"]).to eq(alice.id)
    end
  end

  describe "#expense_created" do
    it "notifies every participant except the creator" do
      expense = create(:expense, created_by: me, paid_by: me)
      create(:expense_split, expense: expense, user: me, amount: 10)
      create(:expense_split, expense: expense, user: alice, amount: 10)

      expect { service.expense_created(expense.reload) }
        .to change { alice.notifications.count }.by(1)

      expect(me.notifications).to be_empty
      expect(alice.notifications.last.notification_type).to eq("expense")
    end
  end

  describe "#settlement_created" do
    let(:friendship) { create(:friendship, user: me, friend: alice) }

    it "notifies the party who did not record it" do
      settlement = create(:settlement, settleable: friendship, created_by: me,
                                       from_user: me, to_user: alice, amount: 10)

      expect { service.settlement_created(settlement) }
        .to change { alice.notifications.count }.by(1)

      expect(me.notifications).to be_empty
    end

    it "notifies both parties when a third party records it" do
      group = create(:group, owner: bob)
      settlement = create(:settlement, settleable: group, created_by: bob,
                                       from_user: me, to_user: alice, amount: 10)

      expect { service.settlement_created(settlement) }
        .to change(Notification, :count).by(2)
    end
  end

  describe "#added_to_group" do
    it "notifies the added user" do
      group = create(:group, owner: me)
      membership = create(:group_member, group: group, user: alice)

      expect { service.added_to_group(membership) }
        .to change { alice.notifications.count }.by(1)

      expect(alice.notifications.last.notification_type).to eq("group_added")
    end
  end

  describe "integration with the domain services (hooks fire)" do
    it "on a friend request" do
      expect { FriendRequestService.new.create(sender: alice, receiver: me) }
        .to change { me.notifications.count }.by(1)
    end

    it "on an expense" do
      create(:friendship, user: me, friend: alice)
      params = { context_type: "friend", friend_id: alice.id, title: "Dinner", amount: "20.00",
                 split_type: "equal", expense_date: Date.current,
                 participants: [{ user_id: me.id }, { user_id: alice.id }] }

      expect { ExpenseService.new.create(creator: me, params: params) }
        .to change { alice.notifications.count }.by(1)
    end

    it "on a settlement" do
      create(:friendship, user: me, friend: alice)
      params = { context_type: "friend", friend_id: alice.id,
                 from_user_id: alice.id, to_user_id: me.id, amount: "5.00" }

      expect { SettlementService.new.create(creator: me, params: params) }
        .to change { alice.notifications.count }.by(1)
    end

    it "on being added to a group" do
      create(:friendship, user: me, friend: alice)
      group = create(:group, :with_owner_membership, owner: me)

      expect { GroupService.new.add_member(group: group, actor: me, user: alice) }
        .to change { alice.notifications.count }.by(1)
    end
  end
end
