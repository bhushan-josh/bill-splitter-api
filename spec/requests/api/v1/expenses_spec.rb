# frozen_string_literal: true

require "rails_helper"
require "bigdecimal"

RSpec.describe "Api::V1::Expenses", type: :request do
  let(:creator) { create(:user) }
  let(:member_a) { create(:user) }
  let(:member_b) { create(:user) }

  # Build a group owned by `creator` with the given users added as members.
  def group_with(members)
    group = GroupService.new.create(owner: creator, attributes: { name: "Trip", description: "Goa" })
    members.each do |user|
      FriendshipService.new.befriend(creator, user)
      GroupService.new.add_member(group: group, actor: creator, user: user)
    end
    group
  end

  def split_amounts(response)
    response.parsed_body.dig("data", "splits").map { |s| BigDecimal(s["amount"]) }
  end

  describe "POST /api/v1/expenses" do
    let(:group) { group_with([member_a, member_b]) }

    it "requires authentication" do
      post "/api/v1/expenses", params: { context_type: "group", group_id: group.id }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    context "equal split (group)" do
      it "splits the amount evenly across participants" do
        post "/api/v1/expenses", params: {
          context_type: "group", group_id: group.id, title: "Dinner",
          amount: "60.00", currency: "USD", split_type: "equal", expense_date: "2026-07-30",
          participants: [{ user_id: creator.id }, { user_id: member_a.id }, { user_id: member_b.id }]
        }, headers: auth_headers(creator), as: :json

        expect(response).to have_http_status(:created)
        expect(split_amounts(response)).to eq([BigDecimal("20"), BigDecimal("20"), BigDecimal("20")])
        expect(Expense.last.expense_splits.count).to eq(3)
      end

      it "distributes rounding remainder so splits still sum to the amount" do
        post "/api/v1/expenses", params: {
          context_type: "group", group_id: group.id, title: "Cab",
          amount: "100.00", split_type: "equal", expense_date: "2026-07-30",
          participants: [{ user_id: creator.id }, { user_id: member_a.id }, { user_id: member_b.id }]
        }, headers: auth_headers(creator), as: :json

        amounts = split_amounts(response)
        expect(amounts).to eq([BigDecimal("33.34"), BigDecimal("33.33"), BigDecimal("33.33")])
        expect(amounts.sum).to eq(BigDecimal("100"))
      end

      it "supports a subset of the group's members" do
        post "/api/v1/expenses", params: {
          context_type: "group", group_id: group.id, title: "Snacks",
          amount: "10.00", split_type: "equal", expense_date: "2026-07-30",
          participants: [{ user_id: creator.id }, { user_id: member_a.id }]
        }, headers: auth_headers(creator), as: :json

        expect(response).to have_http_status(:created)
        expect(Expense.last.expense_splits.count).to eq(2)
      end
    end

    context "percentage split" do
      it "computes amounts from percentages that total 100" do
        post "/api/v1/expenses", params: {
          context_type: "group", group_id: group.id, title: "Hotel",
          amount: "200.00", split_type: "percentage", expense_date: "2026-07-30",
          participants: [{ user_id: creator.id, percentage: "25" }, { user_id: member_a.id, percentage: "75" }]
        }, headers: auth_headers(creator), as: :json

        expect(response).to have_http_status(:created)
        expect(split_amounts(response)).to eq([BigDecimal("50"), BigDecimal("150")])
      end

      it "rejects percentages that do not total 100" do
        post "/api/v1/expenses", params: {
          context_type: "group", group_id: group.id, title: "Hotel",
          amount: "200.00", split_type: "percentage", expense_date: "2026-07-30",
          participants: [{ user_id: creator.id, percentage: "25" }, { user_id: member_a.id, percentage: "50" }]
        }, headers: auth_headers(creator), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body.dig("error", "code")).to eq("invalid_expense")
      end
    end

    context "exact split" do
      it "accepts exact amounts that sum to the total" do
        post "/api/v1/expenses", params: {
          context_type: "group", group_id: group.id, title: "Groceries",
          amount: "50.00", split_type: "exact", expense_date: "2026-07-30",
          participants: [{ user_id: creator.id, amount: "20.00" }, { user_id: member_a.id, amount: "30.00" }]
        }, headers: auth_headers(creator), as: :json

        expect(response).to have_http_status(:created)
        expect(split_amounts(response).sum).to eq(BigDecimal("50"))
      end

      it "rejects exact amounts that do not sum to the total" do
        post "/api/v1/expenses", params: {
          context_type: "group", group_id: group.id, title: "Groceries",
          amount: "50.00", split_type: "exact", expense_date: "2026-07-30",
          participants: [{ user_id: creator.id, amount: "20.00" }, { user_id: member_a.id, amount: "40.00" }]
        }, headers: auth_headers(creator), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "authorization & membership" do
      it "forbids creating an expense in a group you are not a member of" do
        other_group = GroupService.new.create(owner: member_a, attributes: { name: "Not mine" })
        post "/api/v1/expenses", params: {
          context_type: "group", group_id: other_group.id, title: "X",
          amount: "10.00", split_type: "equal", expense_date: "2026-07-30",
          participants: [{ user_id: member_a.id }]
        }, headers: auth_headers(creator), as: :json

        expect(response).to have_http_status(:forbidden)
      end

      it "rejects a participant who is not a group member" do
        stranger = create(:user)
        post "/api/v1/expenses", params: {
          context_type: "group", group_id: group.id, title: "X",
          amount: "10.00", split_type: "equal", expense_date: "2026-07-30",
          participants: [{ user_id: creator.id }, { user_id: stranger.id }]
        }, headers: auth_headers(creator), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "friend expenses" do
      it "creates an expense between accepted friends" do
        FriendshipService.new.befriend(creator, member_a)
        post "/api/v1/expenses", params: {
          context_type: "friend", friend_id: member_a.id, title: "Lunch",
          amount: "40.00", split_type: "equal", expense_date: "2026-07-30",
          participants: [{ user_id: creator.id }, { user_id: member_a.id }]
        }, headers: auth_headers(creator), as: :json

        expect(response).to have_http_status(:created)
        expect(response.parsed_body.dig("data", "context", "type")).to eq("Friendship")
      end

      it "rejects a friend expense when they are not friends" do
        stranger = create(:user)
        post "/api/v1/expenses", params: {
          context_type: "friend", friend_id: stranger.id, title: "Lunch",
          amount: "40.00", split_type: "equal", expense_date: "2026-07-30",
          participants: [{ user_id: creator.id }, { user_id: stranger.id }]
        }, headers: auth_headers(creator), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /api/v1/expenses/:id" do
    let(:group) { group_with([member_a]) }
    let(:expense) do
      ExpenseService.new.create(creator: creator, params: expense_payload(group))
    end

    it "returns the expense to a member" do
      get "/api/v1/expenses/#{expense.id}", headers: auth_headers(member_a)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "id")).to eq(expense.id)
    end

    it "forbids a non-member" do
      stranger = create(:user)
      get "/api/v1/expenses/#{expense.id}", headers: auth_headers(stranger)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/expenses/:id" do
    let(:group) { group_with([member_a]) }
    let(:expense) { ExpenseService.new.create(creator: creator, params: expense_payload(group)) }

    it "lets the creator edit and recompute splits" do
      patch "/api/v1/expenses/#{expense.id}", params: {
        title: "Updated", amount: "90.00", split_type: "equal",
        participants: [{ user_id: creator.id }, { user_id: member_a.id }]
      }, headers: auth_headers(creator), as: :json

      expect(response).to have_http_status(:ok)
      expect(expense.reload.title).to eq("Updated")
      expect(split_amounts(response)).to eq([BigDecimal("45"), BigDecimal("45")])
    end

    it "forbids a non-creator from editing" do
      patch "/api/v1/expenses/#{expense.id}", params: { title: "Hacked" },
                                              headers: auth_headers(member_a), as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/expenses/:id" do
    let(:group) { group_with([member_a]) }
    let(:expense) { ExpenseService.new.create(creator: creator, params: expense_payload(group)) }

    it "lets the creator delete" do
      target = expense # ensure it exists before measuring the change
      expect do
        delete "/api/v1/expenses/#{target.id}", headers: auth_headers(creator), as: :json
      end.to change(Expense, :count).by(-1).and change(ExpenseSplit, :count).by(-2)
      expect(response).to have_http_status(:ok)
    end

    it "forbids a non-creator" do
      delete "/api/v1/expenses/#{expense.id}", headers: auth_headers(member_a), as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  def expense_payload(group)
    {
      context_type: "group", group_id: group.id, title: "Dinner",
      amount: "60.00", currency: "USD", split_type: "equal", expense_date: "2026-07-30",
      participants: [{ user_id: creator.id }, { user_id: member_a.id }]
    }
  end
end
