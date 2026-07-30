# frozen_string_literal: true

module Api
  module V1
    # Base controller for all v1 API endpoints. Wires in the shared JSON
    # response helpers, global error handling, authorization (Pundit) and
    # pagination (Pagy). Authentication will be layered on here later.
    class BaseController < ApplicationController
      include JsonResponders
      include ErrorHandler
      include Pundit::Authorization
      include Pagy::Backend
    end
  end
end
