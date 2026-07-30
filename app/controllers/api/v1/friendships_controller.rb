# frozen_string_literal: true

module Api
  module V1
    class FriendshipsController < BaseController
      # GET /api/v1/friends
      def index
        scope = current_user.friendships.includes(:friend).order(created_at: :desc)
        pagy, friendships = pagy(scope)
        render_collection(pagy, FriendshipSerializer.collection(friendships))
      end

      # DELETE /api/v1/friends/:id  (:id is the friend's user id)
      def destroy
        friend = current_user.friends.find(params[:id])
        FriendshipService.new.unfriend(current_user, friend)
        render_success({ removed_friend_id: friend.id })
      end
    end
  end
end
