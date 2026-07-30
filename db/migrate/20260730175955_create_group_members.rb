# frozen_string_literal: true

class CreateGroupMembers < ActiveRecord::Migration[7.2]
  def change
    create_table :group_members do |t|
      t.references :group, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: { to_table: :users }
      t.datetime :left_at

      t.timestamps
    end

    # A user has at most one membership row per group (reactivated on re-join).
    add_index :group_members, %i[group_id user_id], unique: true
  end
end
