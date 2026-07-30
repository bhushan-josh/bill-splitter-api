# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::FriendRequests", type: :request do
  let(:sender) { create(:user) }
  let(:receiver) { create(:user) }

  describe "POST /api/v1/friend_requests" do
    it "requires authentication" do
      post "/api/v1/friend_requests", params: { receiver_id: receiver.id }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates a pending request" do
      expect do
        post "/api/v1/friend_requests", params: { receiver_id: receiver.id }, headers: auth_headers(sender), as: :json
      end.to change(FriendRequest, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body.dig("data", "status")).to eq("pending")
      expect(body.dig("data", "sender", "id")).to eq(sender.id)
      expect(body.dig("data", "receiver", "id")).to eq(receiver.id)
    end

    it "cannot request yourself" do
      post "/api/v1/friend_requests", params: { receiver_id: sender.id }, headers: auth_headers(sender), as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("error", "code")).to eq("record_invalid")
    end

    it "cannot send a duplicate pending request" do
      create(:friend_request, sender: sender, receiver: receiver)
      post "/api/v1/friend_requests", params: { receiver_id: receiver.id }, headers: auth_headers(sender), as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 for an unknown receiver" do
      post "/api/v1/friend_requests", params: { receiver_id: 0 }, headers: auth_headers(sender), as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "can resend after a previous request was rejected" do
      create(:friend_request, sender: sender, receiver: receiver, status: "rejected")
      expect do
        post "/api/v1/friend_requests", params: { receiver_id: receiver.id }, headers: auth_headers(sender), as: :json
      end.to change(FriendRequest, :count).by(1)
      expect(response).to have_http_status(:created)
    end
  end

  describe "PATCH /api/v1/friend_requests/:id/accept" do
    let!(:friend_request) { create(:friend_request, sender: sender, receiver: receiver) }

    it "lets the receiver accept" do
      patch "/api/v1/friend_requests/#{friend_request.id}/accept", headers: auth_headers(receiver), as: :json
      expect(response).to have_http_status(:ok)
      expect(friend_request.reload).to be_accepted
    end

    it "does not let the sender accept (404 — not their received request)" do
      patch "/api/v1/friend_requests/#{friend_request.id}/accept", headers: auth_headers(sender), as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "does not let an unrelated user accept" do
      patch "/api/v1/friend_requests/#{friend_request.id}/accept", headers: auth_headers(create(:user)), as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "returns 409 when the request is no longer pending" do
      friend_request.update!(status: "accepted")
      patch "/api/v1/friend_requests/#{friend_request.id}/accept", headers: auth_headers(receiver), as: :json
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_transition")
    end
  end

  describe "PATCH /api/v1/friend_requests/:id/reject" do
    let!(:friend_request) { create(:friend_request, sender: sender, receiver: receiver) }

    it "lets the receiver reject" do
      patch "/api/v1/friend_requests/#{friend_request.id}/reject", headers: auth_headers(receiver), as: :json
      expect(response).to have_http_status(:ok)
      expect(friend_request.reload).to be_rejected
    end
  end

  describe "DELETE /api/v1/friend_requests/:id" do
    let!(:friend_request) { create(:friend_request, sender: sender, receiver: receiver) }

    it "lets the sender cancel their request" do
      delete "/api/v1/friend_requests/#{friend_request.id}", headers: auth_headers(sender), as: :json
      expect(response).to have_http_status(:ok)
      expect(friend_request.reload).to be_cancelled
    end

    it "does not let the receiver cancel (404 — not their sent request)" do
      delete "/api/v1/friend_requests/#{friend_request.id}", headers: auth_headers(receiver), as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
