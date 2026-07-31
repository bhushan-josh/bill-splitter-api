# frozen_string_literal: true

# Serializes a totals object (owed / owes / net) into the shared summary shape.
# `object` responds to #owed, #owes and #net (e.g. BalanceCalculator::Totals).
class BalanceTotalsSerializer < ApplicationSerializer
  def as_json(*)
    {
      owed: self.class.money(object.owed),
      owes: self.class.money(object.owes),
      net_balance: self.class.money(object.net)
    }
  end

  # Roll a collection of balances (each responding to #owed / #owes) up into a
  # single formatted summary.
  def self.from_balances(balances)
    owed = balances.sum(BalanceCalculator::ZERO, &:owed)
    owes = balances.sum(BalanceCalculator::ZERO, &:owes)
    new(BalanceCalculator::Totals.new(owed: owed, owes: owes)).as_json
  end
end
