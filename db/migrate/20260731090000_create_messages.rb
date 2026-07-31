# frozen_string_literal: true

class CreateMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :messages do |t|
      t.references :messageable, polymorphic: true, null: false
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false

      t.timestamps
    end

    add_index :messages, %i[messageable_type messageable_id created_at],
              name: "index_messages_on_messageable_and_created_at"
  end
end
