# frozen_string_literal: true

# Serializes a User for API responses. Never exposes password_digest.
class UserSerializer < ApplicationSerializer
  def as_json(*)
    {
      id: object.id,
      name: object.name,
      username: object.username,
      phone: object.phone,
      avatar_url: object.avatar_url,
      fcm_token: object.fcm_token,
      created_at: object.created_at&.iso8601,
      updated_at: object.updated_at&.iso8601
    }
  end
end
