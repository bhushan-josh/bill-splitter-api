# frozen_string_literal: true

module Api
  module V1
    class UsersController < BaseController
      # GET /api/v1/users/search?q=<username-or-phone>
      def search
        query = params[:q].to_s.strip
        if query.blank?
          return render_error("Query parameter 'q' is required",
                              status: :bad_request,
                              code: "parameter_missing")
        end

        scope = User.search(query).where.not(id: current_user.id).order(:username)
        pagy, users = pagy(scope)
        render_collection(pagy, UserSerializer.collection(users))
      end
    end
  end
end
