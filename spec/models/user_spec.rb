# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  it "has a valid factory" do
    expect(user).to be_valid
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_presence_of(:phone) }

    it "requires a unique username (case-insensitive)" do
      create(:user, username: "johndoe")
      dup = build(:user, username: "JohnDoe")
      expect(dup).not_to be_valid
    end

    it "requires a unique phone" do
      create(:user, phone: "+15551230000")
      dup = build(:user, phone: "+15551230000")
      expect(dup).not_to be_valid
    end

    it "rejects a short password" do
      user.password = "123"
      expect(user).not_to be_valid
    end

    it "rejects an invalid phone format" do
      user.phone = "not-a-phone"
      expect(user).not_to be_valid
    end
  end

  describe "secure password" do
    it "authenticates with the correct password" do
      saved = create(:user, password: "password123")
      expect(saved.authenticate("password123")).to eq(saved)
    end

    it "does not authenticate with the wrong password" do
      saved = create(:user, password: "password123")
      expect(saved.authenticate("wrong")).to be(false)
    end

    it "stores a hashed digest, not the raw password" do
      saved = create(:user, password: "password123")
      expect(saved.password_digest).not_to eq("password123")
    end
  end

  describe ".find_for_authentication" do
    let!(:existing) { create(:user, username: "janedoe", phone: "+15559990000") }

    it "finds by username (case-insensitive)" do
      expect(described_class.find_for_authentication("JaneDoe")).to eq(existing)
    end

    it "finds by phone" do
      expect(described_class.find_for_authentication("+15559990000")).to eq(existing)
    end

    it "returns nil for an unknown login" do
      expect(described_class.find_for_authentication("nobody")).to be_nil
    end

    it "returns nil for a blank login" do
      expect(described_class.find_for_authentication("")).to be_nil
    end
  end
end
