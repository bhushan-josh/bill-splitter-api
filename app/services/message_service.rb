# frozen_string_literal: true

# Lists and posts chat messages for a friend chat (Friendship) or a group chat
# (Group). Text only.
#
# A friendship is stored as two directed rows (A→B and B→A). So both
# participants share a single conversation, friend messages are always anchored
# to a canonical row — the one ordered by ascending user ids — which both users
# resolve to identically.
#
# Rules enforced here:
#   * friend chats require an accepted friendship between the two users
#   * group chats require the actor to be an active member
class MessageService
  class NotAuthorized < StandardError; end
  class InvalidMessage < StandardError; end

  # @return [ActiveRecord::Relation] messages for the resolved context, newest
  #   first, with senders eager-loaded. The caller paginates.
  def messages_for(user:, params:)
    messageable = resolve_context!(user, params)
    messageable.messages.includes(:sender).order(created_at: :desc, id: :desc)
  end

  def create(sender:, params:)
    messageable = resolve_context!(sender, params)
    messageable.messages.create!(sender: sender, body: params[:body])
  rescue ActiveRecord::RecordInvalid => e
    raise InvalidMessage, e.record.errors.full_messages.to_sentence
  end

  private

  def resolve_context!(user, params)
    case params[:context_type].to_s
    when "group"
      group = Group.find(params[:group_id])
      raise NotAuthorized, "You are not a member of this group" unless group.active_member?(user)

      group
    when "friend"
      friend_chat!(user, User.find(params[:friend_id]))
    else
      raise InvalidMessage, "context_type must be 'group' or 'friend'"
    end
  end

  # The canonical friendship row for the pair (ascending user ids). Both rows
  # exist for an accepted friendship, so this always resolves when they are
  # friends and both users resolve the same row.
  def friend_chat!(user, friend)
    low, high = [user.id, friend.id].minmax
    Friendship.find_by(user_id: low, friend_id: high) ||
      raise(InvalidMessage, "You can only message accepted friends")
  end
end
