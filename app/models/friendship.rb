# frozen_string_literal: true

# A directed friendship edge (user -> friend). A mutual friendship is stored as
# two rows (A -> B and B -> A); see FriendshipService.
class Friendship < ApplicationRecord
  belongs_to :user, class_name: "User", inverse_of: :friendships
  belongs_to :friend, class_name: "User", inverse_of: :inverse_friendships

  has_many :settlements, as: :settleable, dependent: :destroy

  validates :user_id, uniqueness: { scope: :friend_id }
  validate :not_self_friendship

  private

  def not_self_friendship
    return if user_id.blank? || friend_id.blank?

    errors.add(:friend, "cannot be yourself") if user_id == friend_id
  end
end
