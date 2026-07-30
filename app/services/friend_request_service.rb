# frozen_string_literal: true

# Encapsulates the friend-request lifecycle and its business rules:
#
#   * a user cannot send a request to themselves (enforced by the model)
#   * a user cannot have a duplicate *pending* request with another user
#     (enforced by the model + a partial unique index)
#   * a request may be resent after it was rejected or cancelled, since only
#     pending requests block new ones
#
# Rule violations surface as ActiveRecord::RecordInvalid (create) or
# FriendRequestService::InvalidTransition (accept/reject/cancel), both of which
# are translated to JSON errors by the controller / global ErrorHandler.
class FriendRequestService
  # Raised when a transition is attempted on a non-pending request.
  class InvalidTransition < StandardError; end

  # Create a pending request from sender to receiver.
  #
  # @param sender [User]
  # @param receiver [User]
  # @return [FriendRequest] the persisted, pending request
  # @raise [ActiveRecord::RecordInvalid]
  def create(sender:, receiver:)
    FriendRequest.create!(sender: sender, receiver: receiver, status: "pending")
  end

  # Receiver accepts a pending request. Accepting and creating the mutual
  # friendship happen in a single transaction so they succeed or fail together.
  def accept!(friend_request)
    guard_pending!(friend_request, "accepted")

    ApplicationRecord.transaction do
      friend_request.update!(status: "accepted")
      FriendshipService.new.befriend(friend_request.sender, friend_request.receiver)
    end

    friend_request
  end

  # Receiver rejects a pending request.
  def reject!(friend_request)
    transition!(friend_request, "rejected")
  end

  # Sender cancels their own pending request.
  def cancel!(friend_request)
    transition!(friend_request, "cancelled")
  end

  private

  def transition!(friend_request, new_status)
    guard_pending!(friend_request, new_status)
    friend_request.update!(status: new_status)
    friend_request
  end

  def guard_pending!(friend_request, new_status)
    return if friend_request.pending?

    raise InvalidTransition,
          "This request is already #{friend_request.status} and can no longer be #{new_status}"
  end
end
