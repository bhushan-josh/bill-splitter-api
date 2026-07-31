# frozen_string_literal: true

# Base serializer. A minimal, dependency-free PORO serializer: subclasses
# declare the object they wrap and expose an `#as_json` returning a Hash.
#
# Example:
#   class BillSerializer < ApplicationSerializer
#     def as_json(*)
#       { id: object.id, total: object.total }
#     end
#   end
#
#   BillSerializer.new(bill).as_json
#   BillSerializer.collection(bills)
class ApplicationSerializer
  attr_reader :object, :options

  def initialize(object, options = {})
    @object = object
    @options = options
  end

  def as_json(*)
    raise NoMethodError, "You must define #as_json in #{self.class}"
  end

  # Serialize an enumerable of objects with this serializer.
  def self.collection(objects, options = {})
    Array(objects).map { |object| new(object, options).as_json }
  end

  # Format a monetary value as a fixed 2-decimal string (e.g. "12.50",
  # "-3.00") so JSON consumers never deal with float precision.
  def self.money(value)
    format("%.2f", value || 0)
  end
end
