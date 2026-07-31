# frozen_string_literal: true

# Serializes the friend-balances endpoint payload: a per-friend list plus a
# rolled-up summary. `object` is an Array<BalanceCalculator::Entry>.
class FriendBalancesSerializer < ApplicationSerializer
  def as_json(*)
    {
      summary: BalanceTotalsSerializer.from_balances(object),
      friends: BalanceSerializer.collection(object)
    }
  end
end
