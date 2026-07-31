# frozen_string_literal: true

require "rails_helper"

RSpec.describe Settlement, type: :model do
  subject(:settlement) do
    build(:settlement,
          settleable: friendship,
          from_user: friendship.user,
          to_user: friendship.friend)
  end

  let(:friendship) { create(:friendship) }

  it "has a valid factory" do
    expect(settlement).to be_valid
  end

  it "requires a settleable" do
    settlement.settleable = nil
    expect(settlement).not_to be_valid
  end

  it "requires a positive amount" do
    settlement.amount = 0
    expect(settlement).not_to be_valid
    expect(settlement.errors[:amount]).to be_present
  end

  it "rejects a settlement between the same user" do
    settlement.to_user = settlement.from_user
    expect(settlement).not_to be_valid
    expect(settlement.errors[:to_user]).to include("must be different from the payer")
  end

  it "rejects an over-long note" do
    settlement.note = "x" * 2001
    expect(settlement).not_to be_valid
    expect(settlement.errors[:note]).to be_present
  end
end
