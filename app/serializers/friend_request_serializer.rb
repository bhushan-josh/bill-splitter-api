# frozen_string_literal: true

# Serializes a FriendRequest, embedding the sender and receiver.
class FriendRequestSerializer < ApplicationSerializer
  def as_json(*)
    {
      id: object.id,
      status: object.status,
      sender: UserSerializer.new(object.sender).as_json,
      receiver: UserSerializer.new(object.receiver).as_json,
      created_at: object.created_at&.iso8601,
      updated_at: object.updated_at&.iso8601
    }
  end
end
