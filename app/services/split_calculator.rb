# frozen_string_literal: true

require "bigdecimal"

# Computes per-participant split amounts for an expense and validates that the
# parts reconcile with the total:
#
#   * equal      — the amount is divided evenly, spreading leftover cents
#   * percentage — percentages must total 100; amounts are derived from them
#   * exact      — the given amounts must sum to the total
#
# `call` returns an array of { user_id:, amount:, percentage: } hashes ready to
# be turned into ExpenseSplit records. Raises InvalidSplit on any mismatch.
class SplitCalculator
  class InvalidSplit < StandardError; end

  def initialize(split_type:, amount:)
    @split_type = split_type
    @amount = amount
  end

  # @param entries [Array<Hash>] each { user_id:, amount:, percentage: }
  def call(entries)
    case @split_type
    when "equal" then equal(entries)
    when "percentage" then percentage(entries)
    when "exact" then exact(entries)
    else raise InvalidSplit, "split_type must be one of #{Expense::SPLIT_TYPES.join(", ")}"
    end
  end

  private

  def equal(entries)
    amounts = distribute_evenly(@amount, entries.length)
    entries.each_with_index.map do |entry, index|
      { user_id: entry[:user_id], amount: amounts[index], percentage: nil }
    end
  end

  def percentage(entries)
    percentages = entries.map { |e| to_decimal(e[:percentage]) }
    unless percentages.sum == BigDecimal("100")
      raise InvalidSplit, "Percentages must add up to 100 (got #{percentages.sum.to_s("F")})"
    end

    amounts = allocate_by_percentage(@amount, percentages)
    entries.each_with_index.map do |entry, index|
      { user_id: entry[:user_id], amount: amounts[index], percentage: percentages[index] }
    end
  end

  def exact(entries)
    amounts = entries.map { |e| to_decimal(e[:amount]) }
    unless amounts.sum == @amount
      raise InvalidSplit, "Exact amounts must add up to #{@amount.to_s("F")} (got #{amounts.sum.to_s("F")})"
    end

    entries.each_with_index.map do |entry, index|
      { user_id: entry[:user_id], amount: amounts[index], percentage: nil }
    end
  end

  # Split a monetary amount into `count` parts summing exactly to the total,
  # spreading any leftover cents across the first parts.
  def distribute_evenly(total, count)
    cents = (total * 100).to_i
    base, remainder = cents.divmod(count)
    Array.new(count) { |i| BigDecimal(base + (i < remainder ? 1 : 0)) / 100 }
  end

  # Force the parts to sum exactly to the total by absorbing rounding into the
  # last participant.
  def allocate_by_percentage(total, percentages)
    amounts = percentages.map { |pct| (total * pct / 100).round(2) }
    amounts[-1] += total - amounts.sum
    amounts
  end

  def to_decimal(value)
    BigDecimal(value.to_s)
  rescue ArgumentError, TypeError
    raise InvalidSplit, "Invalid numeric value: #{value.inspect}"
  end
end
