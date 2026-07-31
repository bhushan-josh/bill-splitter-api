# frozen_string_literal: true

# An entry in a group's activity timeline. `actor` is who performed the action,
# `trackable` is the record it concerns (Expense, Settlement, User, Group — nil
# once the record is gone, e.g. a deleted expense), and `metadata` holds a small
# JSON payload with human-readable details so the timeline renders without
# loading the trackable.
class Activity < ApplicationRecord
  ACTIONS = %w[
    group_created group_renamed member_joined member_removed
    expense_created expense_updated expense_deleted settlement_created
  ].freeze

  belongs_to :group
  belongs_to :actor, class_name: "User"
  belongs_to :trackable, polymorphic: true, optional: true

  validates :action, presence: true, inclusion: { in: ACTIONS }

  scope :recent, -> { order(created_at: :desc, id: :desc) }
end
