# frozen_string_literal: true

# Serializes a chat Message with its sender's details.
class MessageSerializer < ApplicationSerializer
  def as_json(*)
    {
      id: object.id,
      body: object.body,
      sender: UserSerializer.new(object.sender).as_json,
      created_at: object.created_at&.iso8601,
      updated_at: object.updated_at&.iso8601
    }
  end
end
