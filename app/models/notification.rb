# frozen_string_literal: true

# An in-app notification for a user. Exposed to the API as `type` (stored as
# `notification_type` to avoid Rails' STI `type` column). `data` holds a small
# JSON payload with the ids needed to deep-link to the related record.
class Notification < ApplicationRecord
  TYPES = %w[friend_request expense settlement group_added].freeze

  belongs_to :user

  enum :notification_type, TYPES.index_with(&:itself), validate: true

  validates :title, presence: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :unread, -> { where(read_at: nil) }

  def read?
    read_at.present?
  end

  # Idempotent: keeps the original timestamp if already read.
  def mark_as_read!
    update!(read_at: Time.current) unless read_at
  end
end
