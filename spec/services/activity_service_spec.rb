# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivityService do
  subject(:service) { described_class.new }

  let(:owner) { create(:user) }
  let(:member) { create(:user) }
  let(:group) { create(:group, owner: owner) }

  describe "#group_created" do
    it "logs the owner as the actor" do
      expect { service.group_created(group) }.to change { group.activities.count }.by(1)
      activity = group.activities.last
      expect(activity).to have_attributes(action: "group_created", actor: owner, trackable: group)
    end
  end

  describe "#group_renamed" do
    it "records the old and new names in metadata" do
      service.group_renamed(group, actor: owner, from: "Old", to: "New")
      expect(group.activities.last.metadata).to include("from" => "Old", "to" => "New")
    end
  end

  describe "#member_joined / #member_removed" do
    it "records the member" do
      service.member_joined(group, actor: owner, member: member)
      service.member_removed(group, actor: owner, member: member)

      expect(group.activities.pluck(:action)).to contain_exactly("member_joined", "member_removed")
      expect(group.activities.last.metadata).to include("member_id" => member.id)
    end
  end

  describe "#expense_created" do
    it "logs a group expense" do
      expense = create(:expense, expenseable: group, created_by: owner, paid_by: owner)
      expect { service.expense_created(expense, actor: owner) }.to change { group.activities.count }.by(1)
      expect(group.activities.last.trackable).to eq(expense)
    end

    it "ignores a friend expense (no group timeline)" do
      expense = create(:expense, expenseable: create(:friendship), created_by: owner, paid_by: owner)
      expect { service.expense_created(expense, actor: owner) }.not_to change(Activity, :count)
    end
  end

  describe "#expense_deleted" do
    it "logs with a nil trackable and preserves details in metadata", :aggregate_failures do
      expense = create(:expense, expenseable: group, created_by: owner, paid_by: owner, title: "Trip", amount: "50.00")

      service.expense_deleted(expense, actor: owner)

      activity = group.activities.last
      expect(activity.action).to eq("expense_deleted")
      expect(activity.trackable).to be_nil
      expect(activity.metadata).to include("title" => "Trip", "amount" => "50.0")
    end
  end

  describe "#settlement_created" do
    it "logs a group settlement" do
      settlement = create(:settlement, settleable: group, created_by: owner, from_user: owner, to_user: member,
                                       amount: "5.00")
      expect { service.settlement_created(settlement) }.to change { group.activities.count }.by(1)
    end

    it "ignores a friend settlement" do
      friendship = create(:friendship, user: owner, friend: member)
      settlement = create(:settlement, settleable: friendship, created_by: owner, from_user: owner, to_user: member,
                                       amount: "5.00")
      expect { service.settlement_created(settlement) }.not_to change(Activity, :count)
    end
  end

  describe "#timeline" do
    it "returns the group's activities newest first" do
      older = create(:activity, group: group, actor: owner, action: "group_created")
      newer = create(:activity, group: group, actor: owner, action: "expense_created")

      expect(service.timeline(group).map(&:id)).to eq([newer.id, older.id])
    end
  end

  describe "generation via the domain services (hooks fire)" do
    let(:friend) { create(:user) }

    def make_group
      GroupService.new.create(owner: owner, attributes: { name: "Trip" })
    end

    it "records group_created" do
      expect { make_group }.to change { Activity.where(action: "group_created").count }.by(1)
    end

    it "records group_renamed only when the name changes" do
      grp = make_group
      GroupService.new.update(group: grp, actor: owner, attributes: { description: "same name" })
      GroupService.new.update(group: grp, actor: owner, attributes: { name: "Renamed" })

      expect(grp.activities.where(action: "group_renamed").count).to eq(1)
    end

    it "records member_joined and member_removed" do
      create(:friendship, user: owner, friend: friend)
      grp = make_group

      GroupService.new.add_member(group: grp, actor: owner, user: friend)
      GroupService.new.remove_member(group: grp, actor: owner, user: friend)

      expect(grp.activities.pluck(:action)).to include("member_joined", "member_removed")
    end

    it "records the full expense lifecycle for a group expense" do
      grp = make_group
      params = { context_type: "group", group_id: grp.id, title: "Lunch", amount: "10.00",
                 split_type: "equal", expense_date: Date.current, participants: [{ user_id: owner.id }] }

      expense = ExpenseService.new.create(creator: owner, params: params)
      ExpenseService.new.update(expense: expense, actor: owner, params: { title: "Lunch v2" })
      ExpenseService.new.destroy(expense: expense, actor: owner)

      expect(grp.activities.pluck(:action)).to include("expense_created", "expense_updated", "expense_deleted")
    end

    it "records settlement_created for a group settlement" do
      grp = make_group
      create(:group_member, group: grp, user: friend)
      params = { context_type: "group", group_id: grp.id, from_user_id: owner.id, to_user_id: friend.id,
                 amount: "5.00" }

      expect { SettlementService.new.create(creator: owner, params: params) }
        .to change { grp.activities.where(action: "settlement_created").count }.by(1)
    end
  end
end
