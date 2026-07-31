# frozen_string_literal: true

# Serializes an Expense with its context, payer/creator and per-participant
# splits. Expects the expense to be loaded with its splits and users eager
# loaded (see ExpensesController) to avoid N+1 queries.
class ExpenseSerializer < ApplicationSerializer
  def as_json(*)
    {
      id: object.id,
      title: object.title,
      description: object.description,
      amount: object.amount.to_s,
      currency: object.currency,
      split_type: object.split_type,
      expense_date: object.expense_date&.iso8601,
      context: context,
      paid_by: UserSerializer.new(object.paid_by).as_json,
      created_by: UserSerializer.new(object.created_by).as_json,
      splits: splits,
      created_at: object.created_at&.iso8601,
      updated_at: object.updated_at&.iso8601
    }
  end

  private

  def context
    { type: object.expenseable_type, id: object.expenseable_id }
  end

  def splits
    object.expense_splits.map do |split|
      {
        user: UserSerializer.new(split.user).as_json,
        amount: split.amount.to_s,
        percentage: split.percentage&.to_s
      }
    end
  end
end
