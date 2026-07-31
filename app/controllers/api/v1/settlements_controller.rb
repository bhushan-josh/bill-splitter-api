# frozen_string_literal: true

module Api
  module V1
    class SettlementsController < BaseController
      rescue_from SettlementService::NotAuthorized, with: :handle_not_authorized_action
      rescue_from SettlementService::InvalidSettlement, with: :handle_invalid_action

      before_action :set_settlement, only: %i[update destroy]

      # POST /api/v1/settlements
      def create
        settlement = service.create(creator: current_user, params: settlement_params)
        render_success(serialize(settlement), status: :created)
      end

      # PATCH /api/v1/settlements/:id  (creator only)
      def update
        settlement = service.update(settlement: @settlement, actor: current_user, params: settlement_params)
        render_success(serialize(settlement))
      end

      # DELETE /api/v1/settlements/:id  (creator only)
      def destroy
        service.destroy(settlement: @settlement, actor: current_user)
        render_success({ deleted_settlement_id: @settlement.id })
      end

      private

      def service
        @service ||= SettlementService.new
      end

      def set_settlement
        @settlement = Settlement.find(params[:id])
      end

      def settlement_params
        params.permit(:context_type, :group_id, :friend_id, :from_user_id, :to_user_id, :amount, :note)
      end

      def serialize(settlement)
        SettlementSerializer.new(settlement).as_json
      end

      def handle_not_authorized_action(exception)
        render_error(exception.message, status: :forbidden, code: "forbidden")
      end

      def handle_invalid_action(exception)
        render_error(exception.message, status: :unprocessable_entity, code: "invalid_settlement")
      end
    end
  end
end
