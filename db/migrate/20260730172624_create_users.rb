# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :username, null: false
      t.string :phone, null: false
      t.string :password_digest, null: false
      t.string :avatar_url
      t.string :fcm_token

      t.timestamps
    end

    add_index :users, :username, unique: true
    add_index :users, :phone, unique: true
  end
end
