# frozen_string_literal: true

# Serializes a single counterparty balance (BalanceCalculator::Entry): the
# counterparty plus owed / owes / net figures as fixed-precision strings.
class BalanceSerializer < ApplicationSerializer
  def as_json(*)
    {
      user: UserSerializer.new(object.user).as_json,
      owed: self.class.money(object.owed),
      owes: self.class.money(object.owes),
      net_balance: self.class.money(object.net)
    }
  end
end
