# frozen_string_literal: true

module Api
  module V1
    class ActivitiesController < BaseController
      before_action :set_group

      # GET /api/v1/groups/:group_id/activities  (members only)
      def index
        return forbid_non_member unless @group.active_member?(current_user)

        pagy, activities = pagy(ActivityService.new.timeline(@group))
        render_collection(pagy, ActivitySerializer.collection(activities))
      end

      private

      def set_group
        @group = Group.find(params[:group_id])
      end

      def forbid_non_member
        render_error("You are not a member of this group", status: :forbidden, code: "forbidden")
      end
    end
  end
end
