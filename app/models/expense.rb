# frozen_string_literal: true

class Expense < ApplicationRecord
  SPLIT_TYPES = %w[equal percentage exact].freeze

  # expenseable is either a Group or a Friendship (friend expense).
  belongs_to :expenseable, polymorphic: true
  belongs_to :paid_by, class_name: "User", inverse_of: :paid_expenses
  belongs_to :created_by, class_name: "User", inverse_of: :created_expenses

  has_many :expense_splits, dependent: :destroy, inverse_of: :expense
  has_many :participants, through: :expense_splits, source: :user

  enum :split_type, SPLIT_TYPES.index_with(&:itself), validate: true

  validates :title, presence: true, length: { maximum: 200 }
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :amount, numericality: { greater_than: 0 }
  validates :currency, presence: true, length: { is: 3 }
  validates :expense_date, presence: true
end
