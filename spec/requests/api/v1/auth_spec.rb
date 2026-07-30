# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  describe "POST /api/v1/signup" do
    let(:valid_params) do
      {
        name: "Ada Lovelace",
        username: "ada",
        phone: "+15551112222",
        password: "password123",
        avatar_url: "https://example.com/ada.png",
        fcm_token: "device-token-abc"
      }
    end

    context "with valid params" do
      it "creates the user and returns a token" do
        expect do
          post "/api/v1/signup", params: valid_params, as: :json
        end.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["success"]).to be(true)
        expect(body.dig("data", "token")).to be_present
        expect(body.dig("data", "user")).to include(
          "username" => "ada",
          "phone" => "+15551112222"
        )
      end

      it "never returns the password digest" do
        post "/api/v1/signup", params: valid_params, as: :json
        expect(response.body).not_to include("password_digest")
      end
    end

    context "with invalid params" do
      it "returns 422 with error details" do
        post "/api/v1/signup", params: valid_params.merge(username: ""), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = response.parsed_body
        expect(body["success"]).to be(false)
        expect(body.dig("error", "code")).to eq("record_invalid")
        expect(body.dig("error", "details")).to be_present
      end

      it "rejects a duplicate username" do
        create(:user, username: "ada")
        post "/api/v1/signup", params: valid_params, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /api/v1/login" do
    before { create(:user, username: "grace", phone: "+15553334444", password: "password123") }

    it "logs in with a username" do
      post "/api/v1/login", params: { login: "grace", password: "password123" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "token")).to be_present
    end

    it "logs in with a phone number" do
      post "/api/v1/login", params: { login: "+15553334444", password: "password123" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "token")).to be_present
    end

    it "logs in with a username regardless of case" do
      post "/api/v1/login", params: { login: "GRACE", password: "password123" }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it "rejects a wrong password with 401" do
      post "/api/v1/login", params: { login: "grace", password: "nope" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_credentials")
    end

    it "rejects an unknown login with 401" do
      post "/api/v1/login", params: { login: "ghost", password: "password123" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
