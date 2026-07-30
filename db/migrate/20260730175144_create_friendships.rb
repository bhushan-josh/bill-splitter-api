# frozen_string_literal: true

class CreateFriendships < ActiveRecord::Migration[7.2]
  def change
    create_table :friendships do |t|
      t.references :user, null: false, foreign_key: { to_table: :users }
      t.references :friend, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    # Each directed friendship row (user -> friend) is unique.
    add_index :friendships, %i[user_id friend_id], unique: true
  end
end
