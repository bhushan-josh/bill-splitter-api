# frozen_string_literal: true

# Creates in-app notifications for domain events and enqueues a background job
# for a future push (FCM). Each event method is called from the service that
# owns the action (friend requests, expenses, settlements, group membership).
#
# Firebase is not integrated yet: FcmPushJob is a placeholder that will deliver
# the push once credentials are wired in.
class NotificationService
  def friend_request_received(friend_request)
    sender = friend_request.sender
    notify(
      user: friend_request.receiver,
      type: "friend_request",
      title: "New friend request",
      body: "#{sender.name} sent you a friend request",
      data: { friend_request_id: friend_request.id, sender_id: sender.id }
    )
  end

  # Notifies every participant of a new expense except its creator.
  def expense_created(expense)
    creator = expense.created_by
    recipient_ids = expense.expense_splits.map(&:user_id).uniq - [creator.id]

    User.where(id: recipient_ids).map do |user|
      notify(
        user: user,
        type: "expense",
        title: "New expense",
        body: %(#{creator.name} added "#{expense.title}"),
        data: { expense_id: expense.id, amount: expense.amount.to_s }
      )
    end
  end

  # Notifies the settlement's parties other than whoever recorded it.
  def settlement_created(settlement)
    creator = settlement.created_by
    recipients = [settlement.from_user, settlement.to_user].uniq(&:id).reject { |user| user.id == creator.id }
    recipients.map { |user| notify_settlement(settlement, user) }
  end

  def added_to_group(membership)
    group = membership.group
    notify(
      user: membership.user,
      type: "group_added",
      title: "Added to a group",
      body: %(You were added to "#{group.name}"),
      data: { group_id: group.id }
    )
  end

  private

  def notify_settlement(settlement, user)
    amount = format("%.2f", settlement.amount)
    notify(
      user: user,
      type: "settlement",
      title: "New settlement",
      body: "#{settlement.from_user.name} paid #{settlement.to_user.name} #{amount}",
      data: { settlement_id: settlement.id, amount: settlement.amount.to_s }
    )
  end

  def notify(user:, type:, title:, body:, data:)
    notification = Notification.create!(
      user: user, notification_type: type, title: title, body: body, data: data
    )
    FcmPushJob.perform_later(notification.id)
    notification
  end
end
