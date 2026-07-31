# frozen_string_literal: true

require "rails_helper"

RSpec.describe Activity, type: :model do
  it "has a valid factory" do
    expect(build(:activity)).to be_valid
  end

  it { is_expected.to belong_to(:group) }
  it { is_expected.to belong_to(:actor).class_name("User") }
  it { is_expected.to belong_to(:trackable).optional }
  it { is_expected.to validate_presence_of(:action) }

  it "rejects an unknown action" do
    expect(build(:activity, action: "bogus")).not_to be_valid
  end
end
