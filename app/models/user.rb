# frozen_string_literal: true

class User < ApplicationRecord
  # Provides #password=, #password_confirmation=, #authenticate and requires
  # the `password_digest` column (bcrypt). Password presence is enforced on
  # create automatically.
  has_secure_password

  has_many :sent_friend_requests,
           class_name: "FriendRequest",
           foreign_key: :sender_id,
           inverse_of: :sender,
           dependent: :destroy
  has_many :received_friend_requests,
           class_name: "FriendRequest",
           foreign_key: :receiver_id,
           inverse_of: :receiver,
           dependent: :destroy

  has_many :friendships, inverse_of: :user, dependent: :destroy
  has_many :inverse_friendships,
           class_name: "Friendship",
           foreign_key: :friend_id,
           inverse_of: :friend,
           dependent: :destroy
  has_many :friends, through: :friendships, source: :friend

  has_many :owned_groups, class_name: "Group", foreign_key: :owner_id, inverse_of: :owner, dependent: :destroy
  has_many :group_memberships, class_name: "GroupMember", inverse_of: :user, dependent: :destroy
  # Groups the user is currently an active member of (left_at IS NULL).
  has_many :groups,
           -> { where(group_members: { left_at: nil }) },
           through: :group_memberships,
           source: :group

  has_many :paid_expenses, class_name: "Expense", foreign_key: :paid_by_id, inverse_of: :paid_by,
                           dependent: :restrict_with_exception
  has_many :created_expenses, class_name: "Expense", foreign_key: :created_by_id, inverse_of: :created_by,
                              dependent: :restrict_with_exception
  has_many :expense_splits, inverse_of: :user, dependent: :destroy

  PHONE_FORMAT = /\A\+?[0-9]{7,15}\z/
  USERNAME_FORMAT = /\A[a-zA-Z0-9_]{3,30}\z/
  USERNAME_MESSAGE = "may only contain letters, numbers and underscores (3-30 chars)"

  validates :name, presence: true, length: { maximum: 100 }
  validates :username,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: USERNAME_FORMAT, message: USERNAME_MESSAGE }
  validates :phone,
            presence: true,
            uniqueness: true,
            format: { with: PHONE_FORMAT, message: "must be a valid phone number" }
  validates :password, length: { minimum: 6 }, allow_nil: true
  validates :avatar_url, length: { maximum: 2048 }, allow_blank: true

  normalizes :username, with: ->(value) { value.to_s.strip.downcase }
  normalizes :phone, with: ->(value) { value.to_s.strip }

  # Case-insensitive partial match on username or phone.
  scope :search, lambda { |query|
    term = "%#{sanitize_sql_like(query.to_s.strip)}%"
    where("username ILIKE :t OR phone ILIKE :t", t: term)
  }

  # Look up a user by either their username or phone (used at login).
  #
  # @param login [String] a username or phone number
  # @return [User, nil]
  def self.find_for_authentication(login)
    value = login.to_s.strip
    return nil if value.blank?

    find_by(username: value.downcase) || find_by(phone: value)
  end
end
