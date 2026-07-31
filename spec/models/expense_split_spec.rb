# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExpenseSplit, type: :model do
  it "has a valid factory" do
    expect(build(:expense_split)).to be_valid
  end

  it { is_expected.to belong_to(:expense) }
  it { is_expected.to belong_to(:user) }

  it "is unique per (expense, user)" do
    existing = create(:expense_split)
    dup = build(:expense_split, expense: existing.expense, user: existing.user)
    expect(dup).not_to be_valid
  end

  it "rejects a percentage above 100" do
    expect(build(:expense_split, percentage: 150)).not_to be_valid
  end
end
