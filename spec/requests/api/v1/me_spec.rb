# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Me", type: :request do
  let(:user) { create(:user) }
  let(:token) { JwtService.encode({ user_id: user.id }) }
  let(:auth_headers) { { "Authorization" => "Bearer #{token}" } }

  describe "GET /api/v1/me" do
    it "returns the current user when authenticated" do
      get "/api/v1/me", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "id")).to eq(user.id)
      expect(response.parsed_body.dig("data", "username")).to eq(user.username)
    end

    it "returns 401 without a token" do
      get "/api/v1/me"

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code")).to eq("unauthorized")
    end

    it "returns 401 with a malformed token" do
      get "/api/v1/me", headers: { "Authorization" => "Bearer not-a-real-token" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with an expired token" do
      expired = JwtService.encode({ user_id: user.id }, exp: -1.hour)
      get "/api/v1/me", headers: { "Authorization" => "Bearer #{expired}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
