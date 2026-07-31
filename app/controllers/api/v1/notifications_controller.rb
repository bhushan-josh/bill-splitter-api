# frozen_string_literal: true

module Api
  module V1
    class NotificationsController < BaseController
      before_action :set_notification, only: :read

      # GET /api/v1/notifications  — the current user's notifications, newest first
      def index
        pagy, notifications = pagy(current_user.notifications.recent)
        render_collection(pagy, NotificationSerializer.collection(notifications))
      end

      # PATCH /api/v1/notifications/:id/read
      def read
        @notification.mark_as_read!
        render_success(NotificationSerializer.new(@notification).as_json)
      end

      private

      def set_notification
        @notification = current_user.notifications.find(params[:id])
      end
    end
  end
end
