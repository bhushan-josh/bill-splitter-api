# frozen_string_literal: true

module Api
  module V1
    class MessagesController < BaseController
      rescue_from MessageService::NotAuthorized, with: :handle_forbidden
      rescue_from MessageService::InvalidMessage, with: :handle_invalid

      # GET /api/v1/messages?context_type=friend&friend_id=... (or context_type=group&group_id=...)
      def index
        pagy, messages = pagy(service.messages_for(user: current_user, params: message_params))
        render_collection(pagy, MessageSerializer.collection(messages))
      end

      # POST /api/v1/messages
      def create
        message = service.create(sender: current_user, params: message_params)
        render_success(MessageSerializer.new(message).as_json, status: :created)
      end

      private

      def service
        @service ||= MessageService.new
      end

      def message_params
        params.permit(:context_type, :group_id, :friend_id, :body)
      end

      def handle_forbidden(exception)
        render_error(exception.message, status: :forbidden, code: "forbidden")
      end

      def handle_invalid(exception)
        render_error(exception.message, status: :unprocessable_entity, code: "invalid_message")
      end
    end
  end
end
