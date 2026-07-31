# frozen_string_literal: true

require "rails_helper"

RSpec.describe FcmPushJob, type: :job do
  it "is a no-op when the notification no longer exists" do
    expect { described_class.new.perform(-1) }.not_to raise_error
  end

  it "runs for a recipient that has a device token" do
    user = create(:user, fcm_token: "device-token")
    notification = create(:notification, user: user)
    expect { described_class.new.perform(notification.id) }.not_to raise_error
  end

  it "skips delivery when the recipient has no device token" do
    user = create(:user, fcm_token: nil)
    notification = create(:notification, user: user)
    expect(described_class.new.perform(notification.id)).to be_nil
  end
end
