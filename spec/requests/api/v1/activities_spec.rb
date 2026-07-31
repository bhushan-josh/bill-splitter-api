# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Activities", type: :request do
  let(:owner) { create(:user) }
  let(:member) { create(:user) }
  let(:stranger) { create(:user) }

  let(:group) do
    g = create(:group, owner: owner)
    [owner, member].each { |user| create(:group_member, group: g, user: user) }
    g
  end

  describe "GET /api/v1/groups/:group_id/activities" do
    before do
      create(:activity, group: group, actor: owner, action: "group_created")
      create(:activity, group: group, actor: owner, action: "expense_created")
    end

    it "requires authentication" do
      get "/api/v1/groups/#{group.id}/activities"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the timeline for a member, newest first, with actor and pagination", :aggregate_failures do
      get "/api/v1/groups/#{group.id}/activities", headers: auth_headers(member)

      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]
      expect(data.pluck("action")).to eq(%w[expense_created group_created])
      expect(data.first["actor"]).to include("id" => owner.id)
      expect(data.first["trackable"]).to include("type" => "Group")
      expect(response.parsed_body.dig("meta", "pagination", "count")).to eq(2)
    end

    it "forbids a non-member" do
      get "/api/v1/groups/#{group.id}/activities", headers: auth_headers(stranger)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
