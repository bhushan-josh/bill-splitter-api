# frozen_string_literal: true

# Serializes the group-balances endpoint payload: a per-group list (each with
# its member breakdown) plus a rolled-up summary. `object` is an
# Array<BalanceCalculator::GroupBalance>.
class GroupBalancesSerializer < ApplicationSerializer
  def as_json(*)
    {
      summary: BalanceTotalsSerializer.from_balances(object),
      groups: object.map { |balance| serialize_group(balance) }
    }
  end

  private

  def serialize_group(balance)
    {
      group: {
        id: balance.group.id,
        name: balance.group.name,
        image_url: balance.group.image_url
      },
      owed: self.class.money(balance.owed),
      owes: self.class.money(balance.owes),
      net_balance: self.class.money(balance.net),
      members: BalanceSerializer.collection(balance.member_balances)
    }
  end
end
