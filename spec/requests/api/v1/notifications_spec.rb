# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Notifications", type: :request do
  let(:me) { create(:user) }
  let(:other) { create(:user) }

  describe "GET /api/v1/notifications" do
    it "requires authentication" do
      get "/api/v1/notifications"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns only the current user's notifications, newest first", :aggregate_failures do
      older = create(:notification, user: me, title: "Older")
      newer = create(:notification, user: me, title: "Newer")
      create(:notification, user: other, title: "Not mine")

      get "/api/v1/notifications", headers: auth_headers(me)

      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]
      expect(data.pluck("id")).to eq([newer.id, older.id])
      expect(data.first).to include("type" => "friend_request", "title" => "Newer", "read_at" => nil)
      expect(response.parsed_body.dig("meta", "pagination", "count")).to eq(2)
    end
  end

  describe "PATCH /api/v1/notifications/:id/read" do
    it "marks the notification as read" do
      notification = create(:notification, user: me)

      patch "/api/v1/notifications/#{notification.id}/read", headers: auth_headers(me), as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "read_at")).to be_present
      expect(notification.reload.read_at).to be_present
    end

    it "returns 404 for another user's notification" do
      notification = create(:notification, user: other)

      patch "/api/v1/notifications/#{notification.id}/read", headers: auth_headers(me), as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
