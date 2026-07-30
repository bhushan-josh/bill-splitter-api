# frozen_string_literal: true

require "rails_helper"

RSpec.describe GroupMember, type: :model do
  it "has a valid factory" do
    expect(build(:group_member)).to be_valid
  end

  it { is_expected.to belong_to(:group) }
  it { is_expected.to belong_to(:user) }

  it "is unique per (group, user)" do
    existing = create(:group_member)
    dup = build(:group_member, group: existing.group, user: existing.user)
    expect(dup).not_to be_valid
  end

  it "#active? reflects left_at" do
    expect(build(:group_member, left_at: nil)).to be_active
    expect(build(:group_member, :departed)).not_to be_active
  end

  it ".active returns only members who have not left" do
    active = create(:group_member)
    create(:group_member, :departed, group: active.group)
    expect(described_class.active).to contain_exactly(active)
  end
end
