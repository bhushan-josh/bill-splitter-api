# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Balances", type: :request do
  let(:me) { create(:user, username: "me_user") }
  let(:alice) { create(:user, username: "alice") }
  let(:bob) { create(:user, username: "bob") }

  def expense_with_splits(context:, payer:, splits:)
    expense = create(:expense, expenseable: context, paid_by: payer, created_by: payer)
    splits.each { |user, amount| create(:expense_split, expense: expense, user: user, amount: amount) }
    expense
  end

  describe "GET /api/v1/balances/friends" do
    let!(:friendship) { create(:friendship, user: me, friend: alice) }

    before do
      expense_with_splits(context: friendship, payer: me, splits: { me => 20, alice => 20 })
      create(:settlement, settleable: friendship, from_user: alice, to_user: me, amount: 5)
    end

    it "requires authentication" do
      get "/api/v1/balances/friends"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns per-friend balances and a summary" do
      get "/api/v1/balances/friends", headers: auth_headers(me)

      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]

      expect(data["summary"]).to eq(
        "owed" => "15.00", "owes" => "0.00", "net_balance" => "15.00"
      )
      expect(data["friends"].size).to eq(1)
      friend = data["friends"].first
      expect(friend["user"]).to include("id" => alice.id, "username" => "alice")
      expect(friend).to include("owed" => "15.00", "owes" => "0.00", "net_balance" => "15.00")
    end
  end

  describe "GET /api/v1/balances/groups" do
    let(:group) { create(:group, owner: me) }

    before do
      expense_with_splits(context: group, payer: me, splits: { me => 10, alice => 10, bob => 10 })
      create(:settlement, settleable: group, from_user: alice, to_user: me, amount: 4)
    end

    it "requires authentication" do
      get "/api/v1/balances/groups"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns per-group balances with a member breakdown", :aggregate_failures do
      get "/api/v1/balances/groups", headers: auth_headers(me)

      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]

      expect(data["summary"]).to eq(
        "owed" => "16.00", "owes" => "0.00", "net_balance" => "16.00"
      )
      expect(data["groups"].size).to eq(1)

      group_balance = data["groups"].first
      expect(group_balance["group"]).to include("id" => group.id, "name" => group.name)
      expect(group_balance).to include("owed" => "16.00", "net_balance" => "16.00")

      members = group_balance["members"].index_by { |m| m["user"]["id"] }
      expect(members[alice.id]["net_balance"]).to eq("6.00")
      expect(members[bob.id]["net_balance"]).to eq("10.00")
    end
  end

  describe "GET /api/v1/balances/overall" do
    let(:friendship) { create(:friendship, user: me, friend: alice) }
    let(:group) { create(:group, owner: me) }

    before do
      friendship_bob = create(:friendship, user: me, friend: bob)
      expense_with_splits(context: friendship, payer: me, splits: { me => 20, alice => 20 })
      create(:settlement, settleable: friendship, from_user: alice, to_user: me, amount: 5)
      expense_with_splits(context: friendship_bob, payer: bob, splits: { me => 30, bob => 30 })
      expense_with_splits(context: group, payer: me, splits: { me => 10, alice => 10, bob => 10 })
      create(:settlement, settleable: group, from_user: alice, to_user: me, amount: 4)
    end

    it "requires authentication" do
      get "/api/v1/balances/overall"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns aggregate owed / owes / net across all scopes" do
      get "/api/v1/balances/overall", headers: auth_headers(me)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to eq(
        "owed" => "31.00", "owes" => "30.00", "net_balance" => "1.00"
      )
    end
  end

  describe "with no activity" do
    it "returns empty collections and zeroed totals" do
      get "/api/v1/balances/overall", headers: auth_headers(me)
      expect(response.parsed_body["data"]).to eq(
        "owed" => "0.00", "owes" => "0.00", "net_balance" => "0.00"
      )

      get "/api/v1/balances/friends", headers: auth_headers(me)
      expect(response.parsed_body.dig("data", "friends")).to eq([])
    end
  end
end
