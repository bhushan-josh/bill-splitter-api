# frozen_string_literal: true

# Serializes a FriendRequest, embedding the sender and receiver. Pass
# `viewer:` (a User) to include a `direction` ("incoming"/"outgoing") relative
# to that user — used by the list endpoint, which mixes both directions.
class FriendRequestSerializer < ApplicationSerializer
  def as_json(*)
    data = {
      id: object.id,
      status: object.status,
      sender: UserSerializer.new(object.sender).as_json,
      receiver: UserSerializer.new(object.receiver).as_json,
      created_at: object.created_at&.iso8601,
      updated_at: object.updated_at&.iso8601
    }
    data[:direction] = direction if options[:viewer]
    data
  end

  private

  def direction
    options[:viewer].id == object.sender_id ? "outgoing" : "incoming"
  end
end
