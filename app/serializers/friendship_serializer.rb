# frozen_string_literal: true

# Serializes a friendship from the owning user's perspective: the friend's
# details plus when the friendship was formed.
class FriendshipSerializer < ApplicationSerializer
  def as_json(*)
    UserSerializer.new(object.friend).as_json.merge(
      friends_since: object.created_at&.iso8601
    )
  end
end
