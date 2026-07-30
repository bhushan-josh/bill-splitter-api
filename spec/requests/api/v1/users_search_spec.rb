# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Users search", type: :request do
  let(:me) { create(:user, username: "me_user", phone: "+15550000001") }

  describe "GET /api/v1/users/search" do
    before do
      create(:user, username: "johnsmith", phone: "+15551230001")
      create(:user, username: "johnny", phone: "+15551230002")
      create(:user, username: "alice", phone: "+15559990001")
    end

    it "requires authentication" do
      get "/api/v1/users/search", params: { q: "john" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "finds users by partial username" do
      get "/api/v1/users/search", params: { q: "john" }, headers: auth_headers(me)

      expect(response).to have_http_status(:ok)
      usernames = response.parsed_body["data"].pluck("username")
      expect(usernames).to contain_exactly("johnsmith", "johnny")
    end

    it "finds users by partial phone" do
      get "/api/v1/users/search", params: { q: "555123" }, headers: auth_headers(me)
      usernames = response.parsed_body["data"].pluck("username")
      expect(usernames).to contain_exactly("johnsmith", "johnny")
    end

    it "excludes the current user from results" do
      get "/api/v1/users/search", params: { q: "me_user" }, headers: auth_headers(me)
      expect(response.parsed_body["data"]).to be_empty
    end

    it "includes pagination metadata" do
      get "/api/v1/users/search", params: { q: "john" }, headers: auth_headers(me)
      expect(response.parsed_body.dig("meta", "pagination")).to include("page" => 1, "count" => 2)
    end

    it "returns 400 when q is missing" do
      get "/api/v1/users/search", headers: auth_headers(me)
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.dig("error", "code")).to eq("parameter_missing")
    end
  end
end
