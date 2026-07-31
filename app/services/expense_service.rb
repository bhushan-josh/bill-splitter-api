# frozen_string_literal: true

require "bigdecimal"

# Creates, updates and deletes expenses together with their per-participant
# splits. All writes happen inside a transaction so an expense and its splits
# are always consistent.
#
# Rules enforced here:
#   * friend expenses require an accepted friendship; participants must be the
#     two friends
#   * group expenses require the actor to be an active member; participants and
#     payer must be active members (a subset of the group is allowed)
#   * only the expense creator may edit or delete it
#   * split totals must reconcile: equal splits sum to the amount, percentages
#     sum to 100, exact amounts sum to the expense amount
class ExpenseService
  class NotAuthorized < StandardError; end
  class InvalidExpense < StandardError; end

  def create(creator:, params:)
    expenseable = resolve_context!(creator, params)

    ApplicationRecord.transaction do
      expense = Expense.new(
        expenseable: expenseable,
        created_by: creator,
        paid_by: resolve_payer!(expenseable, creator, params),
        title: params[:title],
        description: params[:description],
        currency: params[:currency].presence || "USD",
        amount: to_amount(params[:amount]),
        split_type: params[:split_type],
        expense_date: params[:expense_date]
      )
      apply_splits!(expense, expenseable, participant_entries(params))
      expense.save!
      expense
    end
  end

  def update(expense:, actor:, params:)
    authorize_creator!(expense, actor)

    ApplicationRecord.transaction do
      expense.assign_attributes(scalar_attributes(params))
      if rebuild_splits?(params)
        expense.paid_by = resolve_payer!(expense.expenseable, expense.created_by, params) if params.key?(:paid_by_id)
        apply_splits!(expense, expense.expenseable, participant_entries(params))
      end
      expense.save!
      expense
    end

    expense
  end

  def destroy(expense:, actor:)
    authorize_creator!(expense, actor)
    expense.destroy!
  end

  # Read authorization: who may view an expense.
  def ensure_visible!(expense, user)
    return if visible?(expense, user)

    raise NotAuthorized, "You do not have access to this expense"
  end

  private

  # --- Context & authorization ---------------------------------------------

  def resolve_context!(creator, params)
    case params[:context_type].to_s
    when "group"
      group = Group.find(params[:group_id])
      raise NotAuthorized, "You are not a member of this group" unless group.active_member?(creator)

      group
    when "friend"
      friend = User.find(params[:friend_id])
      Friendship.find_by(user: creator, friend: friend) ||
        raise(InvalidExpense, "You can only add expenses with accepted friends")
    else
      raise InvalidExpense, "context_type must be 'group' or 'friend'"
    end
  end

  def resolve_payer!(expenseable, creator, params)
    payer_id = params[:paid_by_id].presence || creator.id
    payer = User.find(payer_id)
    unless member_ids(expenseable).include?(payer.id)
      raise InvalidExpense, "The payer must be a participant of this #{context_label(expenseable)}"
    end

    payer
  end

  def authorize_creator!(expense, actor)
    return if expense.created_by_id == actor.id

    raise NotAuthorized, "Only the expense creator can modify this expense"
  end

  def visible?(expense, user)
    member_ids(expense.expenseable).include?(user.id)
  end

  def member_ids(expenseable)
    case expenseable
    when Group then expenseable.members.pluck(:id)
    when Friendship then [expenseable.user_id, expenseable.friend_id]
    else []
    end
  end

  def context_label(expenseable)
    expenseable.is_a?(Group) ? "group" : "friendship"
  end

  # --- Split building -------------------------------------------------------

  def apply_splits!(expense, expenseable, entries)
    raise InvalidExpense, "At least one participant is required" if entries.empty?

    validate_participants!(expenseable, entries)
    rows = SplitCalculator.new(split_type: expense.split_type, amount: expense.amount).call(entries)

    expense.expense_splits.destroy_all if expense.persisted?
    expense.expense_splits = rows.map { |row| ExpenseSplit.new(row) }
  rescue SplitCalculator::InvalidSplit => e
    raise InvalidExpense, e.message
  end

  def validate_participants!(expenseable, entries)
    ids = entries.pluck(:user_id)
    raise InvalidExpense, "Participants must be unique" if ids.uniq.length != ids.length

    allowed = member_ids(expenseable)
    return if (ids - allowed).empty?

    raise InvalidExpense, "All participants must belong to this #{context_label(expenseable)}"
  end

  # --- Param helpers --------------------------------------------------------

  def participant_entries(params)
    Array(params[:participants]).map do |entry|
      {
        user_id: entry[:user_id].to_i,
        amount: entry[:amount],
        percentage: entry[:percentage]
      }
    end
  end

  def scalar_attributes(params)
    params.slice(:title, :description, :amount, :currency, :split_type,
                 :expense_date).to_h.symbolize_keys.tap do |attrs|
      attrs[:amount] = to_amount(attrs[:amount]) if attrs.key?(:amount)
    end
  end

  def rebuild_splits?(params)
    params.key?(:participants) || params.key?(:amount) || params.key?(:split_type)
  end

  def to_amount(value)
    BigDecimal(value.to_s)
  rescue ArgumentError, TypeError
    raise InvalidExpense, "Invalid numeric value: #{value.inspect}"
  end
end
