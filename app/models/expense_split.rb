# frozen_string_literal: true

class ExpenseSplit < ApplicationRecord
  belongs_to :expense, inverse_of: :expense_splits
  belongs_to :user, inverse_of: :expense_splits

  validates :user_id, uniqueness: { scope: :expense_id }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :percentage,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
            allow_nil: true
end
