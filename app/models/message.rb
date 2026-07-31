# frozen_string_literal: true

# A text message in a chat. `messageable` is either a Friendship (friend chat)
# or a Group (group chat). Text only — no attachments.
class Message < ApplicationRecord
  belongs_to :messageable, polymorphic: true
  belongs_to :sender, class_name: "User", inverse_of: :messages

  validates :body, presence: true, length: { maximum: 5000 }
end
