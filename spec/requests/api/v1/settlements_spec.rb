# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Settlements", type: :request do
  let(:me) { create(:user) }
  let(:alice) { create(:user) }
  let(:bob) { create(:user) }

  def expense_with_splits(context:, payer:, splits:)
    expense = create(:expense, expenseable: context, paid_by: payer, created_by: payer)
    splits.each { |user, amount| create(:expense_split, expense: expense, user: user, amount: amount) }
    expense
  end

  describe "POST /api/v1/settlements" do
    before { create(:friendship, user: me, friend: alice) }

    let(:valid_params) do
      { context_type: "friend", friend_id: alice.id,
        from_user_id: alice.id, to_user_id: me.id, amount: "5.00", note: "dinner" }
    end

    it "requires authentication" do
      post "/api/v1/settlements", params: valid_params, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "records a friend settlement", :aggregate_failures do
      expect do
        post "/api/v1/settlements", params: valid_params, headers: auth_headers(me), as: :json
      end.to change(Settlement, :count).by(1)

      expect(response).to have_http_status(:created)
      data = response.parsed_body["data"]
      expect(data).to include("context_type" => "friend", "amount" => "5.00", "note" => "dinner")
      expect(data["from_user"]).to include("id" => alice.id)
      expect(data["to_user"]).to include("id" => me.id)
      expect(data["group"]).to be_nil
    end

    it "returns a 422 with a consistent error envelope for an invalid party" do
      post "/api/v1/settlements",
           params: valid_params.merge(to_user_id: bob.id),
           headers: auth_headers(me), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["success"]).to be(false)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_settlement")
    end

    it "records a group settlement between two members" do
      group = create(:group, owner: me)
      [me, alice, bob].each { |user| create(:group_member, group: group, user: user) }

      post "/api/v1/settlements",
           params: { context_type: "group", group_id: group.id,
                     from_user_id: alice.id, to_user_id: bob.id, amount: "8.00" },
           headers: auth_headers(me), as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "group")).to include("id" => group.id)
    end
  end

  describe "PATCH /api/v1/settlements/:id" do
    let(:friendship) { create(:friendship, user: me, friend: alice) }
    let(:settlement) do
      create(:settlement, settleable: friendship, created_by: me, from_user: me, to_user: alice, amount: "10.00")
    end

    it "lets the creator update the amount" do
      patch "/api/v1/settlements/#{settlement.id}",
            params: { amount: "12.50" }, headers: auth_headers(me), as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "amount")).to eq("12.50")
      expect(settlement.reload.amount).to eq(BigDecimal("12.5"))
    end

    it "forbids a non-creator from updating" do
      patch "/api/v1/settlements/#{settlement.id}",
            params: { amount: "1.00" }, headers: auth_headers(alice), as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/settlements/:id" do
    let(:friendship) { create(:friendship, user: me, friend: alice) }
    let!(:settlement) do
      create(:settlement, settleable: friendship, created_by: me, from_user: me, to_user: alice, amount: "10.00")
    end

    it "lets the creator delete the settlement" do
      expect do
        delete "/api/v1/settlements/#{settlement.id}", headers: auth_headers(me), as: :json
      end.to change(Settlement, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "deleted_settlement_id")).to eq(settlement.id)
    end

    it "forbids a non-creator from deleting" do
      delete "/api/v1/settlements/#{settlement.id}", headers: auth_headers(alice), as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "settlements immediately affect balances" do
    let!(:friendship) { create(:friendship, user: me, friend: alice) }

    before do
      # I paid; Alice owes me her $20 share.
      expense_with_splits(context: friendship, payer: me, splits: { me => 20, alice => 20 })
    end

    it "reduces the friend balance as soon as a settlement is recorded" do
      get "/api/v1/balances/friends", headers: auth_headers(me)
      expect(response.parsed_body.dig("data", "summary", "net_balance")).to eq("20.00")

      post "/api/v1/settlements",
           params: { context_type: "friend", friend_id: alice.id,
                     from_user_id: alice.id, to_user_id: me.id, amount: "5.00" },
           headers: auth_headers(me), as: :json
      expect(response).to have_http_status(:created)

      get "/api/v1/balances/friends", headers: auth_headers(me)
      expect(response.parsed_body.dig("data", "summary", "net_balance")).to eq("15.00")
    end
  end
end
