# frozen_string_literal: true

# Manages mutual friendships, which are stored as two directed rows
# (A -> B and B -> A). Both rows are always created/removed together inside a
# transaction so the friendship can never end up half-formed.
class FriendshipService
  # Create the mutual friendship between two users. Idempotent: re-running does
  # not create duplicates.
  #
  # @return [Array<Friendship>] the two directed friendship rows
  def befriend(user_a, user_b)
    ApplicationRecord.transaction do
      [
        Friendship.find_or_create_by!(user: user_a, friend: user_b),
        Friendship.find_or_create_by!(user: user_b, friend: user_a)
      ]
    end
  end

  # Remove the mutual friendship between two users (both directed rows).
  #
  # @return [Integer] number of rows deleted
  def unfriend(user_a, user_b)
    ApplicationRecord.transaction do
      Friendship
        .where(user: user_a, friend: user_b)
        .or(Friendship.where(user: user_b, friend: user_a))
        .destroy_all
        .size
    end
  end
end
