# frozen_string_literal: true

module Api
  module V1
    class FriendRequestsController < BaseController
      rescue_from FriendRequestService::InvalidTransition, with: :handle_invalid_transition

      DIRECTIONS = %w[incoming outgoing all].freeze

      # GET /api/v1/friend_requests
      # Lists the current user's friend requests. Query params (all optional):
      #   direction — incoming | outgoing | all   (default: all)
      #   status    — pending | accepted | rejected | cancelled | all
      #               (default: pending)
      def index
        return render_invalid_parameter("direction", DIRECTIONS) unless valid_direction?
        return render_invalid_parameter("status", FriendRequest::STATUSES + %w[all]) unless valid_status?

        scope = direction_scope.includes(:sender, :receiver).order(created_at: :desc, id: :desc)
        scope = scope.where(status: effective_status) if effective_status
        pagy, friend_requests = pagy(scope)
        render_collection(pagy, FriendRequestSerializer.collection(friend_requests, viewer: current_user))
      end

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

      def direction
        params[:direction].presence || "all"
      end

      def direction_scope
        case direction
        when "incoming" then current_user.received_friend_requests
        when "outgoing" then current_user.sent_friend_requests
        else
          FriendRequest.where(sender_id: current_user.id)
                       .or(FriendRequest.where(receiver_id: current_user.id))
        end
      end

      # Defaults to pending; `status=all` clears the filter; a specific status
      # narrows to it.
      def effective_status
        raw = params[:status].presence
        return "pending" if raw.nil?
        return nil if raw == "all"

        raw
      end

      def valid_direction?
        DIRECTIONS.include?(direction)
      end

      def valid_status?
        raw = params[:status].presence
        raw.nil? || raw == "all" || FriendRequest::STATUSES.include?(raw)
      end

      def render_invalid_parameter(name, allowed)
        render_error("#{name} must be one of: #{allowed.join(", ")}",
                     status: :bad_request, code: "invalid_parameter")
      end

      def handle_invalid_transition(exception)
        render_error(exception.message, status: :conflict, code: "invalid_transition")
      end
    end
  end
end
