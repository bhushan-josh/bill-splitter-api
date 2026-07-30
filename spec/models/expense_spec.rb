# frozen_string_literal: true

require "rails_helper"

RSpec.describe Expense, type: :model do
  it "has a valid factory" do
    expect(build(:expense)).to be_valid
  end

  it { is_expected.to belong_to(:expenseable) }
  it { is_expected.to belong_to(:paid_by).class_name("User") }
  it { is_expected.to belong_to(:created_by).class_name("User") }
  it { is_expected.to have_many(:expense_splits).dependent(:destroy) }

  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:expense_date) }

  it "requires a positive amount" do
    expect(build(:expense, amount: 0)).not_to be_valid
  end

  it "defines the expected split types" do
    expect(described_class.split_types.keys).to contain_exactly("equal", "percentage", "exact")
  end
end
