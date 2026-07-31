# frozen_string_literal: true

# Serializes a Settlement: the payer/payee, amount and the context (friend or
# group) it belongs to.
class SettlementSerializer < ApplicationSerializer
  def as_json(*)
    {
      id: object.id,
      context_type: context_type,
      group: group_payload,
      from_user: UserSerializer.new(object.from_user).as_json,
      to_user: UserSerializer.new(object.to_user).as_json,
      amount: self.class.money(object.amount),
      note: object.note,
      created_at: object.created_at&.iso8601,
      updated_at: object.updated_at&.iso8601
    }
  end

  private

  def context_type
    object.settleable_type == "Group" ? "group" : "friend"
  end

  def group_payload
    return unless object.settleable.is_a?(Group)

    { id: object.settleable.id, name: object.settleable.name }
  end
end
