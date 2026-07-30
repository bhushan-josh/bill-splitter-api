# frozen_string_literal: true

# Base class for query objects that encapsulate complex/reusable ActiveRecord
# queries, keeping controllers and models thin.
#
# Example:
#   class UnsettledBillsQuery < ApplicationQuery
#     def call
#       relation.where(settled: false)
#     end
#   end
#
#   UnsettledBillsQuery.call(Bill.all)
class ApplicationQuery
  attr_reader :relation

  def initialize(relation)
    @relation = relation
  end

  def self.call(...)
    new(...).call
  end

  def call
    raise NoMethodError, "You must define #call in #{self.class}"
  end
end
