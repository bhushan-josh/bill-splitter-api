# frozen_string_literal: true

class CreateSettlements < ActiveRecord::Migration[7.2]
  def change
    create_table :settlements do |t|
      t.references :settleable, polymorphic: true, null: false
      t.references :from_user, null: false, foreign_key: { to_table: :users }
      t.references :to_user, null: false, foreign_key: { to_table: :users }
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.text :note

      t.timestamps
    end
  end
end
