# frozen_string_literal: true

# Delivers a notification as a push message via Firebase Cloud Messaging.
#
# FCM is not integrated yet: this job resolves the recipient's device token and
# records intent so the delivery call can be dropped in later without changing
# any callers. It runs on Sidekiq (the app's ActiveJob adapter).
class FcmPushJob < ApplicationJob
  queue_as :default

  def perform(notification_id)
    notification = Notification.find_by(id: notification_id)
    return if notification.nil?

    token = notification.user.fcm_token
    return if token.blank?

    Rails.logger.info(
      "[FcmPushJob] pending FCM push notification_id=#{notification.id} user_id=#{notification.user_id}"
    )
  end
end
