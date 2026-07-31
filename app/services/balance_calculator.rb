# frozen_string_literal: true

require "bigdecimal"

# Derives balances (who owes whom) for a single user directly from persisted
# ExpenseSplits and Settlements. Nothing is stored: every figure is computed on
# demand.
#
# Sign convention — all "net" figures are from the given user's perspective:
#   net > 0  => the counterparty owes the user   (money "owed" to the user)
#   net < 0  => the user owes the counterparty    (money the user "owes")
#
# For a counterparty the net is:
#   (their share of expenses the user paid)
#     - (the user's share of expenses they paid)
#     + (settlements the user paid them)
#     - (settlements they paid the user)
#
# Balances live in two independent scopes, matching how expenses and settlements
# are recorded (polymorphic `expenseable` / `settleable`):
#   * friend balances — netted per counterparty across all friendships
#   * group balances  — netted per counterparty within each group
#
# Query strategy: each scope runs a fixed set of grouped aggregate queries plus
# one bulk load of the referenced users/groups, so cost is independent of how
# many friends, groups, expenses or settlements exist (no N+1).
class BalanceCalculator
  FRIENDSHIP = "Friendship"
  GROUP = "Group"
  ZERO = BigDecimal("0")

  # A single counterparty balance within a scope. `net` is positive when the
  # counterparty owes the user.
  Entry = Struct.new(:user, :net, keyword_init: true) do
    def owed = net.positive? ? net : ZERO
    def owes = net.negative? ? -net : ZERO
  end

  # A user's balance within one group: the per-member balances plus the
  # rolled-up group totals.
  GroupBalance = Struct.new(:group, :member_balances, keyword_init: true) do
    def owed = member_balances.sum(ZERO, &:owed)
    def owes = member_balances.sum(ZERO, &:owes)
    def net = owed - owes
  end

  Totals = Struct.new(:owed, :owes, keyword_init: true) do
    def net = owed - owes
  end

  def initialize(user)
    @user = user
  end

  # @return [Array<Entry>] one entry per counterparty the user shares friend
  #   expenses or settlements with, strongest positive balance first.
  def friend_balances
    nets = net_by_key(FRIENDSHIP, group_scope: false)
    users = User.where(id: nets.keys).index_by(&:id)
    sort_entries(nets.filter_map { |user_id, net| entry_for(users[user_id], net) })
  end

  # @return [Array<GroupBalance>] one entry per group the user has activity in,
  #   strongest positive group balance first.
  def group_balances
    nets = net_by_key(GROUP, group_scope: true)
    return [] if nets.empty?

    groups = Group.where(id: nets.keys.map(&:first).uniq).includes(:owner).index_by(&:id)
    users = User.where(id: nets.keys.map(&:last).uniq).index_by(&:id)
    build_group_balances(nets, groups, users)
  end

  # @return [Totals] the user's aggregate position across both scopes.
  def overall
    nets = net_by_key(FRIENDSHIP, group_scope: false).values +
           net_by_key(GROUP, group_scope: true).values

    Totals.new(
      owed: nets.select(&:positive?).sum(ZERO),
      owes: nets.select(&:negative?).sum(ZERO).abs
    )
  end

  private

  # Merge the four aggregate queries for a scope into a single net-per-key hash.
  # For friend scope the key is the counterparty id; for group scope it is a
  # [group_id, counterparty_id] pair.
  def net_by_key(type, group_scope:)
    # [paid_to_others, my_share_of_theirs, settlements_sent, settlements_received]
    sums = aggregate_sums(type, group_scope)
    keys = sums.flat_map(&:keys).uniq
    keys.index_with do |key|
      paid, mine, sent, received = sums.map { |sum| sum[key] || ZERO }
      paid - mine + sent - received
    end
  end

  def aggregate_sums(type, group_scope)
    [
      paid_for_others(type, group_scope),
      share_of_others_expenses(type, group_scope),
      settlements_sent(type, group_scope),
      settlements_received(type, group_scope)
    ]
  end

  def build_group_balances(nets, groups, users)
    by_group = nets.group_by { |(group_id, _user_id), _net| group_id }
    balances = by_group.filter_map do |group_id, pairs|
      group = groups[group_id]
      GroupBalance.new(group: group, member_balances: member_entries(pairs, users)) if group
    end
    balances.sort_by { |balance| [-balance.net, balance.group.name] }
  end

  def member_entries(pairs, users)
    sort_entries(pairs.filter_map { |(_group_id, user_id), net| entry_for(users[user_id], net) })
  end

  def entry_for(user, net)
    Entry.new(user: user, net: net) if user
  end

  def sort_entries(entries)
    entries.sort_by { |entry| [-entry.net, entry.user.username] }
  end

  # Others' shares of expenses the user paid → they owe the user.
  def paid_for_others(type, group_scope)
    ExpenseSplit.joins(:expense)
                .where(expenses: { expenseable_type: type, paid_by_id: @user.id })
                .where.not(user_id: @user.id)
                .group(*group_keys(group_scope, "expenses.expenseable_id", "expense_splits.user_id"))
                .sum("expense_splits.amount")
  end

  # The user's share of expenses others paid → the user owes them.
  def share_of_others_expenses(type, group_scope)
    ExpenseSplit.joins(:expense)
                .where(expense_splits: { user_id: @user.id }, expenses: { expenseable_type: type })
                .where.not(expenses: { paid_by_id: @user.id })
                .group(*group_keys(group_scope, "expenses.expenseable_id", "expenses.paid_by_id"))
                .sum("expense_splits.amount")
  end

  # Settlements the user paid to others → reduces what the user owes them.
  def settlements_sent(type, group_scope)
    Settlement.where(settleable_type: type, from_user_id: @user.id)
              .group(*group_keys(group_scope, :settleable_id, :to_user_id))
              .sum(:amount)
  end

  # Settlements others paid to the user → reduces what they owe the user.
  def settlements_received(type, group_scope)
    Settlement.where(settleable_type: type, to_user_id: @user.id)
              .group(*group_keys(group_scope, :settleable_id, :from_user_id))
              .sum(:amount)
  end

  # Grouping columns for an aggregate: the counterparty alone for friend scope,
  # or the scope id plus the counterparty for group scope.
  def group_keys(group_scope, scope_column, counterparty_column)
    group_scope ? [scope_column, counterparty_column] : [counterparty_column]
  end
end
