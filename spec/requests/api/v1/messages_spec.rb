# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Messages", type: :request do
  let(:me) { create(:user) }
  let(:alice) { create(:user) }
  let(:bob) { create(:user) }

  # Count the SELECT queries issued while running the block (ignoring schema
  # introspection) — used to prove the index does not N+1 on senders.
  def count_selects(&block)
    count = 0
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql]
      next if payload[:name] == "SCHEMA" || sql !~ /\ASELECT/i

      count += 1
    end
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record", &block)
    count
  end

  describe "friend chat" do
    before { FriendshipService.new.befriend(me, alice) }

    it "requires authentication" do
      get "/api/v1/messages", params: { context_type: "friend", friend_id: alice.id }
      expect(response).to have_http_status(:unauthorized)
    end

    it "posts a message and returns the sender details", :aggregate_failures do
      expect do
        post "/api/v1/messages",
             params: { context_type: "friend", friend_id: alice.id, body: "hello" },
             headers: auth_headers(me), as: :json
      end.to change(Message, :count).by(1)

      expect(response).to have_http_status(:created)
      data = response.parsed_body["data"]
      expect(data).to include("body" => "hello")
      expect(data["sender"]).to include("id" => me.id, "username" => me.username)
    end

    it "returns the conversation to both participants, newest first", :aggregate_failures do
      post "/api/v1/messages", params: { context_type: "friend", friend_id: alice.id, body: "first" },
                               headers: auth_headers(me), as: :json
      post "/api/v1/messages", params: { context_type: "friend", friend_id: me.id, body: "second" },
                               headers: auth_headers(alice), as: :json

      get "/api/v1/messages", params: { context_type: "friend", friend_id: alice.id }, headers: auth_headers(me)
      expect(response).to have_http_status(:ok)
      bodies = response.parsed_body["data"].pluck("body")
      expect(bodies).to eq(%w[second first])
      expect(response.parsed_body.dig("meta", "pagination", "count")).to eq(2)

      # Alice sees the same conversation.
      get "/api/v1/messages", params: { context_type: "friend", friend_id: me.id }, headers: auth_headers(alice)
      expect(response.parsed_body["data"].pluck("body")).to eq(%w[second first])
    end

    it "rejects a blank body" do
      post "/api/v1/messages", params: { context_type: "friend", friend_id: alice.id, body: "" },
                               headers: auth_headers(me), as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_message")
    end
  end

  describe "group chat" do
    let(:group) do
      g = create(:group, owner: me)
      [me, alice].each { |user| create(:group_member, group: g, user: user) }
      g
    end

    it "posts and lists group messages" do
      post "/api/v1/messages", params: { context_type: "group", group_id: group.id, body: "gm all" },
                               headers: auth_headers(alice), as: :json
      expect(response).to have_http_status(:created)

      get "/api/v1/messages", params: { context_type: "group", group_id: group.id }, headers: auth_headers(me)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].first).to include("body" => "gm all")
    end

    it "forbids a non-member" do
      get "/api/v1/messages", params: { context_type: "group", group_id: group.id }, headers: auth_headers(bob)
      expect(response).to have_http_status(:forbidden)
    end

    it "eager-loads senders (no N+1 as messages grow)" do
      [me, alice, me, alice].each do |user|
        create(:message, messageable: group, sender: user, body: "m")
      end

      queries = count_selects do
        get "/api/v1/messages", params: { context_type: "group", group_id: group.id }, headers: auth_headers(me)
      end
      expect(queries).to be <= 8
    end
  end
end
