# frozen_string_literal: true

# Request authentication filter. Included into the API base controller, it
# requires every action to be authenticated by default. Public actions (e.g.
# signup and login) opt out with `skip_before_action :authenticate_user!`.
#
# Depends on the CurrentUser concern for `current_user` and on JsonResponders
# for `render_error`.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  # Halts the request with a 401 unless a valid token resolved a user.
  def authenticate_user!
    return if current_user.present?

    render_error("You must be signed in to access this resource",
                 status: :unauthorized,
                 code: "unauthorized")
  end
end
