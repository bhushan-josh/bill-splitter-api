# frozen_string_literal: true

module Api
  module V1
    # Returns the currently authenticated user's profile.
    class MeController < BaseController
      # GET /api/v1/me
      def show
        render_success(UserSerializer.new(current_user).as_json)
      end
    end
  end
end
