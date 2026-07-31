# frozen_string_literal: true

require "rails_helper"

RSpec.describe Message, type: :model do
  it "has a valid factory" do
    expect(build(:message)).to be_valid
  end

  it { is_expected.to belong_to(:messageable) }
  it { is_expected.to belong_to(:sender).class_name("User") }

  it { is_expected.to validate_presence_of(:body) }

  it "rejects an over-long body" do
    expect(build(:message, body: "x" * 5001)).not_to be_valid
  end
end
