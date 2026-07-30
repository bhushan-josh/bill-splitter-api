# frozen_string_literal: true

# Base presenter for view/response-oriented decoration logic that does not
# belong on the model. Wraps a single object and exposes computed attributes.
#
# Example:
#   class BillPresenter < ApplicationPresenter
#     def formatted_total
#       format("$%.2f", object.total)
#     end
#   end
class ApplicationPresenter
  attr_reader :object

  def initialize(object)
    @object = object
  end
end
