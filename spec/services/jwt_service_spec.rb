# frozen_string_literal: true

require "rails_helper"

RSpec.describe JwtService do
  describe ".encode / .decode" do
    it "round-trips a payload" do
      token = described_class.encode({ user_id: 42 })
      payload = described_class.decode(token)

      expect(payload[:user_id]).to eq(42)
      expect(payload[:exp]).to be_present
    end

    it "raises InvalidToken for a tampered token" do
      token = described_class.encode({ user_id: 1 })
      expect do
        described_class.decode("#{token}tampered")
      end.to raise_error(JwtService::InvalidToken)
    end

    it "raises InvalidToken for an expired token" do
      token = described_class.encode({ user_id: 1 }, exp: -1.second)
      expect { described_class.decode(token) }.to raise_error(JwtService::InvalidToken)
    end
  end
end
