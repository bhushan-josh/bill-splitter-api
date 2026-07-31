# frozen_string_literal: true

# Serializes a Notification. Exposes the stored `notification_type` as `type`.
class NotificationSerializer < ApplicationSerializer
  def as_json(*)
    {
      id: object.id,
      type: object.notification_type,
      title: object.title,
      body: object.body,
      data: object.data,
      read_at: object.read_at&.iso8601,
      created_at: object.created_at&.iso8601
    }
  end
end
