# frozen_string_literal: true

require "rails_helper"

RSpec.describe SettlementService do
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
    context "with a friend context" do
      let!(:friendship) { create(:friendship, user: me, friend: alice) }

      it "records a settlement between the two friends", :aggregate_failures do
        settlement = service.create(
          creator: me,
          params: { context_type: "friend", friend_id: alice.id,
                    from_user_id: me.id, to_user_id: alice.id, amount: "10.00", note: "lunch" }
        )

        expect(settlement).to be_persisted
        expect(settlement.settleable).to eq(friendship)
        expect(settlement.from_user).to eq(me)
        expect(settlement.to_user).to eq(alice)
        expect(settlement.amount).to eq(BigDecimal("10"))
        expect(settlement.created_by).to eq(me)
      end

      it "rejects a party outside the friendship" do
        expect do
          service.create(
            creator: me,
            params: { context_type: "friend", friend_id: alice.id,
                      from_user_id: me.id, to_user_id: bob.id, amount: "10.00" }
          )
        end.to raise_error(SettlementService::InvalidSettlement, /must belong to this friendship/)
      end

      it "rejects settling with someone who is not a friend" do
        expect do
          service.create(
            creator: me,
            params: { context_type: "friend", friend_id: bob.id,
                      from_user_id: me.id, to_user_id: bob.id, amount: "10.00" }
          )
        end.to raise_error(SettlementService::InvalidSettlement, /accepted friends/)
      end
    end

    context "with a group context" do
      let(:group) { group_with_members(alice, bob, owner: me) }

      it "records a settlement between two members, even if the creator is not a party" do
        settlement = service.create(
          creator: me,
          params: { context_type: "group", group_id: group.id,
                    from_user_id: alice.id, to_user_id: bob.id, amount: "5.00" }
        )

        expect(settlement).to be_persisted
        expect(settlement.settleable).to eq(group)
        expect(settlement.from_user).to eq(alice)
        expect(settlement.to_user).to eq(bob)
      end

      it "forbids a non-member from creating a settlement" do
        stranger = create(:user)
        expect do
          service.create(
            creator: stranger,
            params: { context_type: "group", group_id: group.id,
                      from_user_id: alice.id, to_user_id: bob.id, amount: "5.00" }
          )
        end.to raise_error(SettlementService::NotAuthorized, /not a member/)
      end

      it "rejects a party who is not an active member" do
        outsider = create(:user)
        expect do
          service.create(
            creator: me,
            params: { context_type: "group", group_id: group.id,
                      from_user_id: alice.id, to_user_id: outsider.id, amount: "5.00" }
          )
        end.to raise_error(SettlementService::InvalidSettlement, /must belong to this group/)
      end
    end

    context "with invalid input" do
      before { create(:friendship, user: me, friend: alice) }

      def create_friend_settlement(overrides)
        service.create(
          creator: me,
          params: { context_type: "friend", friend_id: alice.id,
                    from_user_id: me.id, to_user_id: alice.id, amount: "10.00" }.merge(overrides)
        )
      end

      it "rejects a non-positive amount" do
        expect { create_friend_settlement(amount: "0") }
          .to raise_error(SettlementService::InvalidSettlement)
      end

      it "rejects a non-numeric amount" do
        expect { create_friend_settlement(amount: "abc") }
          .to raise_error(SettlementService::InvalidSettlement, /Invalid numeric value/)
      end

      it "rejects the same payer and payee" do
        expect { create_friend_settlement(to_user_id: me.id) }
          .to raise_error(SettlementService::InvalidSettlement, /different from the payer/)
      end

      it "requires both parties" do
        expect { create_friend_settlement(to_user_id: nil) }
          .to raise_error(SettlementService::InvalidSettlement, /required/)
      end

      it "rejects an unknown context type" do
        expect do
          service.create(creator: me, params: { context_type: "planet", amount: "1.00" })
        end.to raise_error(SettlementService::InvalidSettlement, /context_type/)
      end
    end
  end

  describe "#update" do
    let!(:friendship) { create(:friendship, user: me, friend: alice) }
    let(:settlement) do
      create(:settlement, settleable: friendship, created_by: me,
                          from_user: me, to_user: alice, amount: "10.00")
    end

    it "lets the creator change the amount and note" do
      service.update(settlement: settlement, actor: me, params: { amount: "12.50", note: "updated" })

      expect(settlement.reload.amount).to eq(BigDecimal("12.5"))
      expect(settlement.note).to eq("updated")
    end

    it "re-validates parties when they change" do
      expect do
        service.update(settlement: settlement, actor: me, params: { to_user_id: bob.id })
      end.to raise_error(SettlementService::InvalidSettlement, /must belong to this friendship/)
    end

    it "forbids a non-creator from updating" do
      expect do
        service.update(settlement: settlement, actor: alice, params: { amount: "1.00" })
      end.to raise_error(SettlementService::NotAuthorized)
    end
  end

  describe "#destroy" do
    let!(:friendship) { create(:friendship, user: me, friend: alice) }
    let(:settlement) do
      create(:settlement, settleable: friendship, created_by: me, from_user: me, to_user: alice, amount: "10.00")
    end

    it "lets the creator delete the settlement" do
      settlement
      expect { service.destroy(settlement: settlement, actor: me) }.to change(Settlement, :count).by(-1)
    end

    it "forbids a non-creator from deleting" do
      expect do
        service.destroy(settlement: settlement, actor: alice)
      end.to raise_error(SettlementService::NotAuthorized)
    end
  end
end
