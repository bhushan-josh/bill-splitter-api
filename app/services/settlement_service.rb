# frozen_string_literal: true

require "bigdecimal"

# Creates, updates and deletes settlements — a payment from one user to another
# that pays down debt, scoped to a Friendship or a Group. Settlements feed
# directly into BalanceCalculator, so every change here immediately changes the
# derived balances (nothing is precomputed or cached).
#
# Rules enforced here:
#   * friend settlements require an accepted friendship; both parties must be
#     the two friends
#   * group settlements require the actor to be an active member; both parties
#     must be active members
#   * payer and payee must be provided and distinct
#   * only the settlement creator may edit or delete it
class SettlementService
  class NotAuthorized < StandardError; end
  class InvalidSettlement < StandardError; end

  def create(creator:, params:)
    settleable = resolve_context!(creator, params)
    from_user, to_user = resolve_parties!(settleable, params[:from_user_id], params[:to_user_id])

    settlement = Settlement.create!(
      settleable: settleable,
      created_by: creator,
      from_user: from_user,
      to_user: to_user,
      amount: to_amount(params[:amount]),
      note: params[:note]
    )
    NotificationService.new.settlement_created(settlement)
    settlement
  rescue ActiveRecord::RecordInvalid => e
    raise InvalidSettlement, e.record.errors.full_messages.to_sentence
  end

  def update(settlement:, actor:, params:)
    authorize_creator!(settlement, actor)

    settlement.assign_attributes(scalar_attributes(params))
    reassign_parties!(settlement, params) if params.key?(:from_user_id) || params.key?(:to_user_id)
    settlement.save!
    settlement
  rescue ActiveRecord::RecordInvalid => e
    raise InvalidSettlement, e.record.errors.full_messages.to_sentence
  end

  def destroy(settlement:, actor:)
    authorize_creator!(settlement, actor)
    settlement.destroy!
  end

  private

  def resolve_context!(creator, params)
    case params[:context_type].to_s
    when "group"
      group = Group.find(params[:group_id])
      raise NotAuthorized, "You are not a member of this group" unless group.active_member?(creator)

      group
    when "friend"
      friend = User.find(params[:friend_id])
      Friendship.find_by(user: creator, friend: friend) ||
        raise(InvalidSettlement, "You can only settle up with accepted friends")
    else
      raise InvalidSettlement, "context_type must be 'group' or 'friend'"
    end
  end

  def reassign_parties!(settlement, params)
    settlement.from_user, settlement.to_user =
      resolve_parties!(settlement.settleable,
                       params[:from_user_id] || settlement.from_user_id,
                       params[:to_user_id] || settlement.to_user_id)
  end

  def resolve_parties!(settleable, from_id, to_id)
    raise InvalidSettlement, "from_user_id and to_user_id are required" if from_id.blank? || to_id.blank?

    from_user = User.find(from_id)
    to_user = User.find(to_id)
    allowed = member_ids(settleable)
    unless allowed.include?(from_user.id) && allowed.include?(to_user.id)
      raise InvalidSettlement, "Both parties must belong to this #{context_label(settleable)}"
    end

    [from_user, to_user]
  end

  def authorize_creator!(settlement, actor)
    return if settlement.created_by_id == actor.id

    raise NotAuthorized, "Only the settlement creator can modify this settlement"
  end

  def member_ids(settleable)
    case settleable
    when Group then settleable.members.pluck(:id)
    when Friendship then [settleable.user_id, settleable.friend_id]
    else []
    end
  end

  def context_label(settleable)
    settleable.is_a?(Group) ? "group" : "friendship"
  end

  def scalar_attributes(params)
    {}.tap do |attrs|
      attrs[:amount] = to_amount(params[:amount]) if params.key?(:amount)
      attrs[:note] = params[:note] if params.key?(:note)
    end
  end

  def to_amount(value)
    BigDecimal(value.to_s)
  rescue ArgumentError, TypeError
    raise InvalidSettlement, "Invalid numeric value: #{value.inspect}"
  end
end
