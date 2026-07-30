# frozen_string_literal: true

module Api
  module V1
    # Base controller for all v1 API endpoints. Wires in the shared JSON
    # response helpers, global error handling, authentication, authorization
    # (Pundit) and pagination (Pagy).
    #
    # Authentication is required by default; public endpoints opt out with
    # `skip_before_action :authenticate_user!`.
    class BaseController < ApplicationController
      include JsonResponders
      include ErrorHandler
      include CurrentUser
      include Authentication
      include Pundit::Authorization
      include Pagy::Backend
    end
  end
end
