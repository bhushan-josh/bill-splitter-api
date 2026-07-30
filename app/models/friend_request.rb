# frozen_string_literal: true

class FriendRequest < ApplicationRecord
  STATUSES = %w[pending accepted rejected cancelled].freeze

  belongs_to :sender, class_name: "User", inverse_of: :sent_friend_requests
  belongs_to :receiver, class_name: "User", inverse_of: :received_friend_requests

  enum :status, STATUSES.index_with(&:itself), default: "pending", validate: true

  validate :sender_is_not_receiver
  validate :no_existing_pending_request, on: :create

  scope :between, lambda { |a, b|
    where(sender_id: a, receiver_id: b).or(where(sender_id: b, receiver_id: a))
  }

  private

  def sender_is_not_receiver
    return if sender_id.blank? || receiver_id.blank?

    errors.add(:receiver, "cannot be yourself") if sender_id == receiver_id
  end

  def no_existing_pending_request
    return if sender_id.blank? || receiver_id.blank?

    exists = FriendRequest.pending.between(sender_id, receiver_id).exists?
    errors.add(:base, "A pending friend request already exists between these users") if exists
  end
end
