# frozen_string_literal: true

module Api
  module V1
    class GroupsController < BaseController
      rescue_from GroupService::NotAuthorized, with: :handle_not_authorized_action
      rescue_from GroupService::InvalidAction, with: :handle_invalid_action

      before_action :set_group, except: %i[index create]

      # GET /api/v1/groups  — groups the current user is an active member of
      def index
        # Eager-load owner and members so GroupSerializer's `members_count`
        # (members.size) never fires a per-group COUNT query.
        scope = current_user.groups.includes(:owner, :members).order(created_at: :desc)
        pagy, groups = pagy(scope)
        render_collection(pagy, GroupSerializer.collection(groups))
      end

      # GET /api/v1/groups/:id
      def show
        return forbid_non_member unless @group.active_member?(current_user)

        render_success(serialize(@group))
      end

      # POST /api/v1/groups
      def create
        group = service.create(owner: current_user, attributes: group_params)
        render_success(serialize(group), status: :created)
      end

      # PATCH /api/v1/groups/:id  (owner only)
      def update
        service.update(group: @group, actor: current_user, attributes: group_params)
        render_success(serialize(@group))
      end

      # DELETE /api/v1/groups/:id  (owner only)
      def destroy
        service.destroy(group: @group, actor: current_user)
        render_success({ deleted_group_id: @group.id })
      end

      # POST /api/v1/groups/:id/members  (owner only; params: { user_id })
      def add_member
        service.add_member(group: @group, actor: current_user, user: find_user(:user_id))
        render_success(serialize(@group), status: :created)
      end

      # DELETE /api/v1/groups/:id/members/:user_id  (owner only)
      def remove_member
        service.remove_member(group: @group, actor: current_user, user: find_user(:user_id))
        render_success(serialize(@group))
      end

      # POST /api/v1/groups/:id/leave
      def leave
        service.leave(group: @group, user: current_user)
        render_success({ left_group_id: @group.id })
      end

      # POST /api/v1/groups/:id/transfer_owner  (owner only; params: { new_owner_id })
      def transfer_owner
        service.transfer_owner(group: @group, actor: current_user, new_owner: find_user(:new_owner_id))
        render_success(serialize(@group.reload))
      end

      private

      def service
        @service ||= GroupService.new
      end

      def set_group
        @group = Group.find(params[:id])
      end

      def find_user(key)
        User.find(params[key])
      end

      def group_params
        params.permit(:name, :description, :image_url)
      end

      def serialize(group)
        GroupSerializer.new(group, include_members: true).as_json
      end

      def forbid_non_member
        render_error("You are not a member of this group", status: :forbidden, code: "forbidden")
      end

      def handle_not_authorized_action(exception)
        render_error(exception.message, status: :forbidden, code: "forbidden")
      end

      def handle_invalid_action(exception)
        render_error(exception.message, status: :unprocessable_entity, code: "invalid_action")
      end
    end
  end
end
