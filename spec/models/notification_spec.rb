# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notification, type: :model do
  it "has a valid factory" do
    expect(build(:notification)).to be_valid
  end

  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:title) }

  it "is invalid with an unknown type" do
    notification = build(:notification)
    notification.notification_type = "bogus"
    expect(notification).not_to be_valid
  end

  describe "#mark_as_read!" do
    it "sets read_at and is idempotent" do
      notification = create(:notification)
      expect(notification.read?).to be(false)

      notification.mark_as_read!
      first_read_at = notification.reload.read_at
      expect(first_read_at).to be_present

      notification.mark_as_read!
      expect(notification.reload.read_at).to eq(first_read_at)
    end
  end
end
