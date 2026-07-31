# frozen_string_literal: true

# Encapsulates group lifecycle and membership rules:
#
#   * only the owner can edit, delete, add/remove members, or transfer ownership
#   * only the actor's friends can be added as members
#   * the owner cannot leave without first transferring ownership
#
# Authorization failures raise NotAuthorized (403) and rule violations raise
# InvalidAction (422); both are rendered as JSON by the controller.
class GroupService
  class NotAuthorized < StandardError; end
  class InvalidAction < StandardError; end

  # Create a group and add the owner as its first member (atomically).
  def create(owner:, attributes:)
    group = ApplicationRecord.transaction do
      record = Group.create!(attributes.merge(owner: owner))
      record.group_members.create!(user: owner)
      record
    end
    ActivityService.new.group_created(group)
    group
  end

  def update(group:, actor:, attributes:)
    authorize_owner!(group, actor)
    previous_name = group.name
    group.update!(attributes)
    if group.saved_change_to_name?
      ActivityService.new.group_renamed(group, actor: actor, from: previous_name, to: group.name)
    end
    group
  end

  def destroy(group:, actor:)
    authorize_owner!(group, actor)
    group.destroy!
  end

  # Owner adds one of their friends to the group. Re-adds a previously departed
  # member by clearing left_at.
  def add_member(group:, actor:, user:)
    authorize_owner!(group, actor)
    raise InvalidAction, "You can only add your friends to a group" unless friends?(actor, user)

    membership = group.group_members.find_or_initialize_by(user: user)
    raise InvalidAction, "User is already a member of this group" if membership.persisted? && membership.active?

    membership.left_at = nil
    membership.save!
    NotificationService.new.added_to_group(membership)
    ActivityService.new.member_joined(group, actor: actor, member: user)
    membership
  end

  # Owner removes a member (soft-leave). The owner cannot be removed this way.
  def remove_member(group:, actor:, user:)
    authorize_owner!(group, actor)
    raise InvalidAction, "The owner cannot be removed; transfer ownership first" if group.owner?(user)

    depart!(active_membership!(group, user))
    ActivityService.new.member_removed(group, actor: actor, member: user)
  end

  # A member leaves the group. The owner must transfer ownership first.
  def leave(group:, user:)
    raise InvalidAction, "Transfer ownership before leaving the group" if group.owner?(user)

    depart!(active_membership!(group, user))
    ActivityService.new.member_removed(group, actor: user, member: user)
  end

  # Owner hands ownership to another active member.
  def transfer_owner(group:, actor:, new_owner:)
    authorize_owner!(group, actor)
    raise InvalidAction, "The new owner must be an active member of the group" unless group.active_member?(new_owner)

    group.update!(owner: new_owner)
    group
  end

  private

  def authorize_owner!(group, actor)
    return if group.owner?(actor)

    raise NotAuthorized, "Only the group owner can perform this action"
  end

  def friends?(actor, user)
    actor.friends.exists?(id: user.id)
  end

  def active_membership!(group, user)
    group.group_members.active.find_by(user: user) ||
      raise(InvalidAction, "User is not an active member of this group")
  end

  def depart!(membership)
    membership.update!(left_at: Time.current)
    membership
  end
end
