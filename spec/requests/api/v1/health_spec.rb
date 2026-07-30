# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Health", type: :request do
  describe "GET /api/v1/health" do
    before { get "/api/v1/health" }

    it "returns a 200 OK" do
      expect(response).to have_http_status(:ok)
    end

    it "returns the standard success envelope" do
      body = response.parsed_body
      expect(body["success"]).to be(true)
      expect(body["data"]).to include(
        "status" => "ok",
        "service" => "billsplitter-api",
        "version" => "v1"
      )
    end

    it "reports dependency health" do
      dependencies = response.parsed_body.dig("data", "dependencies")
      expect(dependencies).to include("database" => "ok", "redis" => "ok")
    end
  end
end
