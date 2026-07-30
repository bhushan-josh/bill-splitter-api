# frozen_string_literal: true

class Group < ApplicationRecord
  belongs_to :owner, class_name: "User", inverse_of: :owned_groups

  has_many :group_members, dependent: :destroy
  # Active members only (users who have not left).
  has_many :members,
           -> { where(group_members: { left_at: nil }) },
           through: :group_members,
           source: :user

  validates :name, presence: true, length: { maximum: 150 }
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :image_url, length: { maximum: 2048 }, allow_blank: true

  def owner?(user)
    owner_id == user&.id
  end

  def active_member?(user)
    group_members.active.exists?(user_id: user&.id)
  end
end
