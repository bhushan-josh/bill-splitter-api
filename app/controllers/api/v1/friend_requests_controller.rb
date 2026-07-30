# frozen_string_literal: true

module Api
  module V1
    class FriendRequestsController < BaseController
      rescue_from FriendRequestService::InvalidTransition, with: :handle_invalid_transition

      # POST /api/v1/friend_requests
      # params: { receiver_id: <id> }
      def create
        receiver = User.find(params[:receiver_id])
        friend_request = service.create(sender: current_user, receiver: receiver)
        render_success(FriendRequestSerializer.new(friend_request).as_json, status: :created)
      end

      # PATCH /api/v1/friend_requests/:id/accept  (only the receiver)
      def accept
        friend_request = current_user.received_friend_requests.find(params[:id])
        service.accept!(friend_request)
        render_success(FriendRequestSerializer.new(friend_request).as_json)
      end

      # PATCH /api/v1/friend_requests/:id/reject  (only the receiver)
      def reject
        friend_request = current_user.received_friend_requests.find(params[:id])
        service.reject!(friend_request)
        render_success(FriendRequestSerializer.new(friend_request).as_json)
      end

      # DELETE /api/v1/friend_requests/:id  (cancel — only the sender)
      def destroy
        friend_request = current_user.sent_friend_requests.find(params[:id])
        service.cancel!(friend_request)
        render_success(FriendRequestSerializer.new(friend_request).as_json)
      end

      private

      def service
        @service ||= FriendRequestService.new
      end

      def handle_invalid_transition(exception)
        render_error(exception.message, status: :conflict, code: "invalid_transition")
      end
    end
  end
end
