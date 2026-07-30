# frozen_string_literal: true

class User < ApplicationRecord
  # Provides #password=, #password_confirmation=, #authenticate and requires
  # the `password_digest` column (bcrypt). Password presence is enforced on
  # create automatically.
  has_secure_password

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
