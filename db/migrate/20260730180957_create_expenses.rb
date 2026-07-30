# frozen_string_literal: true

class CreateExpenses < ActiveRecord::Migration[7.2]
  def change
    create_table :expenses do |t|
      t.references :expenseable, polymorphic: true, null: false
      t.references :paid_by, null: false, foreign_key: { to_table: :users }
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :description
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :currency, null: false, default: "USD"
      t.string :split_type, null: false
      t.date :expense_date, null: false

      t.timestamps
    end
  end
end
