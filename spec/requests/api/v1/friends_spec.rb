# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Friends", type: :request do
  let(:me) { create(:user) }
  let(:friend) { create(:user) }

  describe "accepting a friend request creates a mutual friendship" do
    let(:sender) { create(:user) }
    let!(:friend_request) { create(:friend_request, sender: sender, receiver: me) }

    it "creates two friendship rows atomically" do
      expect do
        patch "/api/v1/friend_requests/#{friend_request.id}/accept", headers: auth_headers(me), as: :json
      end.to change(Friendship, :count).by(2)

      expect(response).to have_http_status(:ok)
      expect(me.reload.friends).to include(sender)
      expect(sender.reload.friends).to include(me)
    end
  end

  describe "GET /api/v1/friends" do
    before { FriendshipService.new.befriend(me, friend) }

    it "requires authentication" do
      get "/api/v1/friends"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the current user's friends with details" do
      get "/api/v1/friends", headers: auth_headers(me)

      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]
      expect(data.size).to eq(1)
      expect(data.first).to include("id" => friend.id, "username" => friend.username)
      expect(data.first).to have_key("friends_since")
    end

    it "does not leak the other direction to non-friends" do
      other = create(:user)
      get "/api/v1/friends", headers: auth_headers(other)
      expect(response.parsed_body["data"]).to be_empty
    end

    it "includes pagination metadata" do
      get "/api/v1/friends", headers: auth_headers(me)
      expect(response.parsed_body.dig("meta", "pagination")).to include("page" => 1, "count" => 1)
    end
  end

  describe "DELETE /api/v1/friends/:id" do
    before { FriendshipService.new.befriend(me, friend) }

    it "removes both friendship rows" do
      expect do
        delete "/api/v1/friends/#{friend.id}", headers: auth_headers(me), as: :json
      end.to change(Friendship, :count).by(-2)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "removed_friend_id")).to eq(friend.id)
      expect(me.reload.friends).to be_empty
    end

    it "returns 404 when the target is not a friend" do
      stranger = create(:user)
      delete "/api/v1/friends/#{stranger.id}", headers: auth_headers(me), as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
