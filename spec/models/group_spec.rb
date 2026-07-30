# frozen_string_literal: true

require "rails_helper"

RSpec.describe Group, type: :model do
  it "has a valid factory" do
    expect(build(:group)).to be_valid
  end

  it { is_expected.to belong_to(:owner).class_name("User") }
  it { is_expected.to validate_presence_of(:name) }

  describe "membership helpers" do
    let(:owner) { create(:user) }
    let(:group) { create(:group, owner: owner) }

    it "#owner? is true for the owner" do
      expect(group.owner?(owner)).to be(true)
    end

    it "counts only active members" do
      active = create(:user)
      departed = create(:user)
      create(:group_member, group: group, user: active)
      create(:group_member, :departed, group: group, user: departed)

      expect(group.members).to include(active)
      expect(group.members).not_to include(departed)
    end
  end
end
