# frozen_string_literal: true

# Serializes an Activity timeline entry: the actor, the action, a light
# reference to the trackable (type + id, from columns so a deleted record does
# not need loading), and the metadata payload.
class ActivitySerializer < ApplicationSerializer
  def as_json(*)
    {
      id: object.id,
      action: object.action,
      actor: UserSerializer.new(object.actor).as_json,
      trackable: trackable_ref,
      metadata: object.metadata,
      created_at: object.created_at&.iso8601
    }
  end

  private

  def trackable_ref
    return if object.trackable_type.blank?

    { type: object.trackable_type, id: object.trackable_id }
  end
end
