# frozen_string_literal: true

# Root controller for the API. Includes the shared JSON response helpers so
# that even framework-level fallbacks (e.g. unmatched routes) can emit the
# standard error envelope.
class ApplicationController < ActionController::API
  include JsonResponders

  # Catch-all for any request that does not match a defined route.
  def route_not_found
    render_error("The requested resource could not be found", status: :not_found, code: "not_found")
  end
end
