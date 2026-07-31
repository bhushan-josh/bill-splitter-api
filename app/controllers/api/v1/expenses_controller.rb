# frozen_string_literal: true

module Api
  module V1
    class ExpensesController < BaseController
      rescue_from ExpenseService::NotAuthorized, with: :handle_forbidden
      rescue_from ExpenseService::InvalidExpense, with: :handle_invalid_expense

      before_action :set_expense, only: %i[show update destroy]

      # GET /api/v1/expenses/:id
      def show
        service.ensure_visible!(@expense, current_user)
        render_success(serialize(@expense))
      end

      # POST /api/v1/expenses
      def create
        expense = service.create(creator: current_user, params: expense_params)
        render_success(serialize(expense), status: :created)
      end

      # PATCH /api/v1/expenses/:id  (creator only)
      def update
        service.update(expense: @expense, actor: current_user, params: expense_params)
        render_success(serialize(@expense.reload))
      end

      # DELETE /api/v1/expenses/:id  (creator only)
      def destroy
        service.destroy(expense: @expense, actor: current_user)
        render_success({ deleted_expense_id: @expense.id })
      end

      private

      def service
        @service ||= ExpenseService.new
      end

      def set_expense
        @expense = Expense
                   .includes(:paid_by, :created_by, :expenseable, expense_splits: :user)
                   .find(params[:id])
      end

      def serialize(expense)
        ExpenseSerializer.new(expense).as_json
      end

      def expense_params
        params.permit(
          :context_type, :group_id, :friend_id,
          :title, :description, :amount, :currency, :paid_by_id, :split_type, :expense_date,
          participants: %i[user_id amount percentage]
        )
      end

      def handle_forbidden(exception)
        render_error(exception.message, status: :forbidden, code: "forbidden")
      end

      def handle_invalid_expense(exception)
        render_error(exception.message, status: :unprocessable_entity, code: "invalid_expense")
      end
    end
  end
end
