# frozen_string_literal: true

module Api
  module V1
    # Handles account creation and login. Both actions are public — they are
    # the entry points that mint JWTs, so they skip the authentication filter.
    class AuthController < BaseController
      skip_before_action :authenticate_user!

      # POST /api/v1/signup
      def signup
        user = User.create!(signup_params)
        render_success(auth_payload(user), status: :created)
      end

      # POST /api/v1/login
      def login
        user = User.find_for_authentication(params[:login])

        if user&.authenticate(params[:password].to_s)
          render_success(auth_payload(user))
        else
          render_error("Invalid username/phone or password",
                       status: :unauthorized,
                       code: "invalid_credentials")
        end
      end

      private

      def signup_params
        params.permit(:name, :username, :phone, :password, :password_confirmation, :avatar_url, :fcm_token)
      end

      def auth_payload(user)
        {
          user: UserSerializer.new(user).as_json,
          token: JwtService.encode({ user_id: user.id })
        }
      end
    end
  end
end
