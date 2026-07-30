# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Unmatched routes", type: :request do
  it "returns the standard JSON error envelope with 404" do
    get "/api/v1/this-route-does-not-exist"

    expect(response).to have_http_status(:not_found)
    body = response.parsed_body
    expect(body["success"]).to be(false)
    expect(body.dig("error", "code")).to eq("not_found")
  end
end
