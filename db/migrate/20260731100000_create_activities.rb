# frozen_string_literal: true

class CreateActivities < ActiveRecord::Migration[7.2]
  def change
    create_table :activities do |t|
      t.references :group, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.references :trackable, polymorphic: true, null: true
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :activities, %i[group_id created_at]
  end
end
