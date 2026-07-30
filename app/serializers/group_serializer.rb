# frozen_string_literal: true

# Serializes a Group. Pass `include_members: true` to embed the active member
# list (used on the show endpoint).
class GroupSerializer < ApplicationSerializer
  def as_json(*)
    data = {
      id: object.id,
      name: object.name,
      description: object.description,
      image_url: object.image_url,
      owner: UserSerializer.new(object.owner).as_json,
      members_count: object.members.size,
      created_at: object.created_at&.iso8601,
      updated_at: object.updated_at&.iso8601
    }
    data[:members] = UserSerializer.collection(object.members) if options[:include_members]
    data
  end
end
