# frozen_string_literal: true

class CreateExpenseSplits < ActiveRecord::Migration[7.2]
  def change
    create_table :expense_splits do |t|
      t.references :expense, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: { to_table: :users }
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.decimal :percentage, precision: 5, scale: 2

      t.timestamps
    end

    # A user appears at most once per expense.
    add_index :expense_splits, %i[expense_id user_id], unique: true
  end
end
