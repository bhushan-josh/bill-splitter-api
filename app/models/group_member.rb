# frozen_string_literal: true

class GroupMember < ApplicationRecord
  belongs_to :group, inverse_of: :group_members
  belongs_to :user, inverse_of: :group_memberships

  validates :user_id, uniqueness: { scope: :group_id }

  scope :active, -> { where(left_at: nil) }

  def active?
    left_at.nil?
  end
end
