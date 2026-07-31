# frozen_string_literal: true

require "rails_helper"

RSpec.describe BalanceCalculator do
  let(:me) { create(:user, username: "me_user") }
  let(:alice) { create(:user, username: "alice") }
  let(:bob) { create(:user, username: "bob") }

  # Build an expense scoped to `context` (a Friendship or Group), paid by
  # `payer`, with the given { user => amount } shares.
  def expense_with_splits(context:, payer:, splits:)
    expense = create(:expense, expenseable: context, paid_by: payer, created_by: payer)
    splits.each { |user, amount| create(:expense_split, expense: expense, user: user, amount: amount) }
    expense
  end

  # Count the SELECT queries issued while running the block (ignoring the
  # transactional bookkeeping and schema introspection RSpec adds).
  def count_selects(&block)
    count = 0
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql]
      next if payload[:name] == "SCHEMA" || sql !~ /\ASELECT/i

      count += 1
    end
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record", &block)
    count
  end

  describe "#friend_balances" do
    let(:friendship_alice) { create(:friendship, user: me, friend: alice) }
    let(:friendship_bob) { create(:friendship, user: me, friend: bob) }

    before do
      # I paid; Alice's $20 share means she owes me $20.
      expense_with_splits(context: friendship_alice, payer: me, splits: { me => 20, alice => 20 })
      # Alice repays $5 → she now owes me $15.
      create(:settlement, settleable: friendship_alice, from_user: alice, to_user: me, amount: 5)
      # Bob paid; my $30 share means I owe Bob $30.
      expense_with_splits(context: friendship_bob, payer: bob, splits: { me => 30, bob => 30 })
    end

    it "nets expenses and settlements per counterparty", :aggregate_failures do
      by_user = described_class.new(me).friend_balances.index_by { |e| e.user.id }

      expect(by_user[alice.id].net).to eq(BigDecimal("15"))
      expect(by_user[alice.id].owed).to eq(BigDecimal("15"))
      expect(by_user[alice.id].owes).to eq(BigDecimal("0"))

      expect(by_user[bob.id].net).to eq(BigDecimal("-30"))
      expect(by_user[bob.id].owed).to eq(BigDecimal("0"))
      expect(by_user[bob.id].owes).to eq(BigDecimal("30"))
    end

    it "sorts strongest positive balance first" do
      entries = described_class.new(me).friend_balances
      expect(entries.map { |e| e.user.id }).to eq([alice.id, bob.id])
    end

    it "reports the mirror balance from the other user's perspective" do
      entry = described_class.new(alice).friend_balances.find { |e| e.user.id == me.id }
      expect(entry.net).to eq(BigDecimal("-15"))
    end

    it "runs a bounded number of queries regardless of counterparty count" do
      # Add more friends with expenses to prove the query count is constant.
      3.times do |i|
        other = create(:user, username: "friend_#{i}")
        friendship = create(:friendship, user: me, friend: other)
        expense_with_splits(context: friendship, payer: me, splits: { me => 5, other => 5 })
      end

      queries = count_selects { described_class.new(me).friend_balances }
      # Four aggregate queries + one bulk user load, independent of friend count.
      expect(queries).to be <= 5
    end
  end

  describe "#group_balances" do
    let(:group) { create(:group, owner: me) }

    before do
      # I paid $30; Alice and Bob each owe me their $10 share.
      expense_with_splits(context: group, payer: me, splits: { me => 10, alice => 10, bob => 10 })
      # Alice repays $4 → she owes me $6; Bob still owes $10.
      create(:settlement, settleable: group, from_user: alice, to_user: me, amount: 4)
    end

    it "nets balances per member within the group", :aggregate_failures do
      balances = described_class.new(me).group_balances
      expect(balances.size).to eq(1)

      balance = balances.first
      expect(balance.group).to eq(group)
      expect(balance.owed).to eq(BigDecimal("16"))
      expect(balance.owes).to eq(BigDecimal("0"))
      expect(balance.net).to eq(BigDecimal("16"))

      by_user = balance.member_balances.index_by { |m| m.user.id }
      expect(by_user[alice.id].net).to eq(BigDecimal("6"))
      expect(by_user[bob.id].net).to eq(BigDecimal("10"))
    end

    it "keeps group balances separate from friend balances" do
      expect(described_class.new(me).friend_balances).to be_empty
    end
  end

  describe "#overall" do
    let(:friendship) { create(:friendship, user: me, friend: alice) }
    let(:group) { create(:group, owner: me) }

    before do
      # Friend scope: Alice owes me $15, I owe Bob $30 (via a second friendship).
      friendship_bob = create(:friendship, user: me, friend: bob)
      expense_with_splits(context: friendship, payer: me, splits: { me => 20, alice => 20 })
      create(:settlement, settleable: friendship, from_user: alice, to_user: me, amount: 5)
      expense_with_splits(context: friendship_bob, payer: bob, splits: { me => 30, bob => 30 })
      # Group scope: Alice owes me $6, Bob owes me $10.
      expense_with_splits(context: group, payer: me, splits: { me => 10, alice => 10, bob => 10 })
      create(:settlement, settleable: group, from_user: alice, to_user: me, amount: 4)
    end

    it "aggregates owed and owes across both scopes" do
      totals = described_class.new(me).overall

      expect(totals.owed).to eq(BigDecimal("31")) # 15 (alice, friend) + 6 + 10 (group)
      expect(totals.owes).to eq(BigDecimal("30")) # 30 (bob, friend)
      expect(totals.net).to eq(BigDecimal("1"))
    end
  end

  describe "an empty ledger" do
    it "returns no balances and zeroed totals" do
      calculator = described_class.new(me)
      expect(calculator.friend_balances).to be_empty
      expect(calculator.group_balances).to be_empty
      expect(calculator.overall.net).to eq(BigDecimal("0"))
    end
  end
end
