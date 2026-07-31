# frozen_string_literal: true

# Records and reads group activity-timeline entries. Each domain service calls
# the relevant event method after its action succeeds. Expense and settlement
# events are only logged when they belong to a group (friend-context ones have
# no group timeline).
class ActivityService
  # @return [ActiveRecord::Relation] the group's timeline, newest first, with
  #   actors eager-loaded. The caller paginates.
  def timeline(group)
    group.activities.recent.includes(:actor)
  end

  def group_created(group)
    log(group: group, actor: group.owner, action: "group_created", trackable: group)
  end

  def group_renamed(group, actor:, from:, to:)
    log(group: group, actor: actor, action: "group_renamed", trackable: group,
        metadata: { from: from, to: to })
  end

  def member_joined(group, actor:, member:)
    log(group: group, actor: actor, action: "member_joined", trackable: member,
        metadata: member_metadata(member))
  end

  def member_removed(group, actor:, member:)
    log(group: group, actor: actor, action: "member_removed", trackable: member,
        metadata: member_metadata(member))
  end

  def expense_created(expense, actor:)
    log_expense(expense, actor, "expense_created")
  end

  def expense_updated(expense, actor:)
    log_expense(expense, actor, "expense_updated")
  end

  # Called before the expense row is destroyed; trackable is left nil and the
  # details are preserved in metadata.
  def expense_deleted(expense, actor:)
    group = group_for(expense.expenseable)
    return unless group

    log(group: group, actor: actor, action: "expense_deleted", metadata: expense_metadata(expense))
  end

  def settlement_created(settlement)
    group = group_for(settlement.settleable)
    return unless group

    log(group: group, actor: settlement.created_by, action: "settlement_created", trackable: settlement,
        metadata: { amount: settlement.amount.to_s, from_user_id: settlement.from_user_id,
                    to_user_id: settlement.to_user_id })
  end

  private

  def log_expense(expense, actor, action)
    group = group_for(expense.expenseable)
    return unless group

    log(group: group, actor: actor, action: action, trackable: expense, metadata: expense_metadata(expense))
  end

  def group_for(context)
    context if context.is_a?(Group)
  end

  def member_metadata(member)
    { member_id: member.id, member_name: member.name }
  end

  def expense_metadata(expense)
    { expense_id: expense.id, title: expense.title, amount: expense.amount.to_s }
  end

  def log(group:, actor:, action:, trackable: nil, metadata: {})
    Activity.create!(group: group, actor: actor, action: action, trackable: trackable, metadata: metadata)
  end
end
