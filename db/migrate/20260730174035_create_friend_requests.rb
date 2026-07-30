# frozen_string_literal: true

class CreateFriendRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :friend_requests do |t|
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.references :receiver, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    # A user may have at most one *pending* request toward a given user.
    # Rejected/cancelled/accepted requests are kept for history and allow a
    # fresh request to be sent later.
    add_index :friend_requests,
              %i[sender_id receiver_id],
              unique: true,
              where: "status = 'pending'",
              name: "index_friend_requests_pending_pair"
  end
end
