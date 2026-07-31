# frozen_string_literal: true

# A payment from one user to another that settles debt, scoped to a Friendship
# or a Group (polymorphic settleable). Balances are derived from these rows
# together with expense splits; nothing is precomputed.
class Settlement < ApplicationRecord
  belongs_to :settleable, polymorphic: true
  belongs_to :from_user, class_name: "User", inverse_of: :settlements_made
  belongs_to :to_user, class_name: "User", inverse_of: :settlements_received
  belongs_to :created_by, class_name: "User"

  validates :amount, numericality: { greater_than: 0 }
  validates :note, length: { maximum: 2000 }, allow_blank: true
  validate :distinct_parties

  private

  def distinct_parties
    return if from_user_id.blank? || to_user_id.blank?

    errors.add(:to_user, "must be different from the payer") if from_user_id == to_user_id
  end
end
