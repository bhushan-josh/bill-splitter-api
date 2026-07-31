# frozen_string_literal: true

module Api
  module V1
    # Read-only balance views for the current user. All figures are derived on
    # demand by BalanceCalculator from expense splits and settlements.
    class BalancesController < BaseController
      # GET /api/v1/balances/friends
      def friends
        render_success(FriendBalancesSerializer.new(calculator.friend_balances).as_json)
      end

      # GET /api/v1/balances/groups
      def groups
        render_success(GroupBalancesSerializer.new(calculator.group_balances).as_json)
      end

      # GET /api/v1/balances/overall
      def overall
        render_success(BalanceTotalsSerializer.new(calculator.overall).as_json)
      end

      private

      def calculator
        @calculator ||= BalanceCalculator.new(current_user)
      end
    end
  end
end
