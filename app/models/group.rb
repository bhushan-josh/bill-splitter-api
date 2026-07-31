# frozen_string_literal: true

class Group < ApplicationRecord
  belongs_to :owner, class_name: "User", inverse_of: :owned_groups

  has_many :group_members, dependent: :destroy
  # Active members only (users who have not left).
  has_many :members,
           -> { where(group_members: { left_at: nil }) },
           through: :group_members,
           source: :user
  # Polymorphic children scoped to this group. They carry no database foreign
  # key (the columns are polymorphic), so destroying them must be driven from
  # here to avoid orphaned rows.
  has_many :expenses, as: :expenseable, dependent: :destroy
  has_many :settlements, as: :settleable, dependent: :destroy
  has_many :messages, as: :messageable, dependent: :destroy
  has_many :activities, dependent: :destroy

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
