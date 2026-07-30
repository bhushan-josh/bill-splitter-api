# frozen_string_literal: true

# Base class for service objects that encapsulate a single business action.
#
# Example:
#   class SplitBill < ApplicationService
#     def initialize(bill, among:)
#       @bill = bill
#       @among = among
#     end
#
#     def call
#       # ...perform work, return a result
#     end
#   end
#
#   SplitBill.call(bill, among: users)
class ApplicationService
  # Instantiate with the given arguments and invoke #call.
  def self.call(...)
    new(...).call
  end

  def call
    raise NoMethodError, "You must define #call in #{self.class}"
  end
end
