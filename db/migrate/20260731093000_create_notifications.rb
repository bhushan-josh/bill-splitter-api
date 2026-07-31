# frozen_string_literal: true

class CreateNotifications < ActiveRecord::Migration[7.2]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body
      # Stored as `notification_type` to avoid Rails' STI `type` column.
      t.string :notification_type, null: false
      t.jsonb :data, null: false, default: {}
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, %i[user_id created_at]
    add_index :notifications, %i[user_id read_at]
  end
end
