# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Groups", type: :request do
  let(:owner) { create(:user) }
  let(:friend) { create(:user) }
  let(:stranger) { create(:user) }

  # A persisted group with the owner already a member (as GroupService.create does).
  def create_group(for_owner = owner)
    GroupService.new.create(owner: for_owner, attributes: { name: "Trip", description: "Goa" })
  end

  def make_friends(user_a, user_b)
    FriendshipService.new.befriend(user_a, user_b)
  end

  describe "POST /api/v1/groups" do
    it "requires authentication" do
      post "/api/v1/groups", params: { name: "Trip" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates a group and adds the owner as a member" do
      expect do
        post "/api/v1/groups", params: { name: "Trip", description: "Goa" }, headers: auth_headers(owner), as: :json
      end.to change(Group, :count).by(1).and change(GroupMember, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body.dig("data", "owner", "id")).to eq(owner.id)
      expect(body.dig("data", "members_count")).to eq(1)
    end

    it "rejects a group without a name" do
      post "/api/v1/groups", params: { description: "no name" }, headers: auth_headers(owner), as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /api/v1/groups" do
    it "lists only groups the user is a member of" do
      mine = create_group
      create_group(stranger) # someone else's group

      get "/api/v1/groups", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body["data"].pluck("id")
      expect(ids).to contain_exactly(mine.id)
    end

    it "does not issue a per-group members_count query (no N+1)" do
      3.times { |i| GroupService.new.create(owner: owner, attributes: { name: "G#{i}" }) }

      count_queries = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        # The per-group members_count query counts members FROM "users"; the
        # single pagination COUNT runs FROM "groups" and is expected.
        count_queries << payload[:sql] if payload[:sql].match?(/COUNT\(\*\)\s+FROM "users"/i)
      end
      get "/api/v1/groups", headers: auth_headers(owner)
      ActiveSupport::Notifications.unsubscribe(subscriber)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].pluck("members_count")).to all(eq(1))
      expect(count_queries).to be_empty
    end
  end

  describe "GET /api/v1/groups/:id" do
    let(:group) { create_group }

    it "returns the group with members for a member" do
      get "/api/v1/groups/#{group.id}", headers: auth_headers(owner)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "members").pluck("id")).to include(owner.id)
    end

    it "forbids non-members" do
      get "/api/v1/groups/#{group.id}", headers: auth_headers(stranger)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/groups/:id" do
    let(:group) { create_group }

    it "lets the owner edit" do
      patch "/api/v1/groups/#{group.id}", params: { name: "Renamed" }, headers: auth_headers(owner), as: :json
      expect(response).to have_http_status(:ok)
      expect(group.reload.name).to eq("Renamed")
    end

    it "forbids non-owners from editing" do
      make_friends(owner, friend)
      GroupService.new.add_member(group: group, actor: owner, user: friend)

      patch "/api/v1/groups/#{group.id}", params: { name: "Hacked" }, headers: auth_headers(friend), as: :json
      expect(response).to have_http_status(:forbidden)
      expect(group.reload.name).to eq("Trip")
    end
  end

  describe "DELETE /api/v1/groups/:id" do
    let(:group) { create_group }

    it "lets the owner delete" do
      delete "/api/v1/groups/#{group.id}", headers: auth_headers(owner), as: :json
      expect(response).to have_http_status(:ok)
      expect(Group.exists?(group.id)).to be(false)
    end

    it "forbids non-owners" do
      delete "/api/v1/groups/#{group.id}", headers: auth_headers(stranger), as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "cascades to the group's expenses and their splits" do
      expense = create(:expense, expenseable: group, paid_by: owner, created_by: owner)
      create(:expense_split, expense: expense, user: owner)

      expect do
        delete "/api/v1/groups/#{group.id}", headers: auth_headers(owner), as: :json
      end.to change(Expense, :count).by(-1).and change(ExpenseSplit, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/groups/:id/members" do
    let(:group) { create_group }

    it "lets the owner add a friend" do
      make_friends(owner, friend)
      expect do
        post "/api/v1/groups/#{group.id}/members", params: { user_id: friend.id },
                                                   headers: auth_headers(owner), as: :json
      end.to change { group.members.count }.by(1)
      expect(response).to have_http_status(:created)
    end

    it "cannot add a non-friend" do
      post "/api/v1/groups/#{group.id}/members", params: { user_id: stranger.id },
                                                 headers: auth_headers(owner), as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_action")
    end

    it "forbids a non-owner from adding members" do
      make_friends(friend, stranger)
      make_friends(owner, friend)
      GroupService.new.add_member(group: group, actor: owner, user: friend)

      post "/api/v1/groups/#{group.id}/members", params: { user_id: stranger.id },
                                                 headers: auth_headers(friend), as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/groups/:id/members/:user_id" do
    let(:group) { create_group }

    before do
      make_friends(owner, friend)
      GroupService.new.add_member(group: group, actor: owner, user: friend)
    end

    it "lets the owner remove a member" do
      delete "/api/v1/groups/#{group.id}/members/#{friend.id}", headers: auth_headers(owner), as: :json
      expect(response).to have_http_status(:ok)
      expect(group.reload.members).not_to include(friend)
    end

    it "cannot remove the owner" do
      delete "/api/v1/groups/#{group.id}/members/#{owner.id}", headers: auth_headers(owner), as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/groups/:id/leave" do
    let(:group) { create_group }

    before do
      make_friends(owner, friend)
      GroupService.new.add_member(group: group, actor: owner, user: friend)
    end

    it "lets a member leave" do
      post "/api/v1/groups/#{group.id}/leave", headers: auth_headers(friend), as: :json
      expect(response).to have_http_status(:ok)
      expect(group.reload.members).not_to include(friend)
    end

    it "does not let the owner leave without transferring ownership" do
      post "/api/v1/groups/#{group.id}/leave", headers: auth_headers(owner), as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("error", "message")).to match(/transfer ownership/i)
    end
  end

  describe "POST /api/v1/groups/:id/transfer_owner" do
    let(:group) { create_group }

    before do
      make_friends(owner, friend)
      GroupService.new.add_member(group: group, actor: owner, user: friend)
    end

    it "transfers ownership to an active member" do
      post "/api/v1/groups/#{group.id}/transfer_owner", params: { new_owner_id: friend.id },
                                                        headers: auth_headers(owner), as: :json
      expect(response).to have_http_status(:ok)
      expect(group.reload.owner).to eq(friend)
    end

    it "cannot transfer to a non-member" do
      post "/api/v1/groups/#{group.id}/transfer_owner", params: { new_owner_id: stranger.id },
                                                        headers: auth_headers(owner), as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "lets the previous owner leave after transferring" do
      GroupService.new.transfer_owner(group: group, actor: owner, new_owner: friend)
      post "/api/v1/groups/#{group.id}/leave", headers: auth_headers(owner), as: :json
      expect(response).to have_http_status(:ok)
    end
  end
end
