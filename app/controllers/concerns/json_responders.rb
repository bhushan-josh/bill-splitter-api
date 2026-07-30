# frozen_string_literal: true

# Provides a consistent JSON envelope for all API responses.
#
# Success:
#   { "success": true, "data": <payload>, "meta": <optional metadata> }
#
# Error:
#   { "success": false, "error": { "message": ..., "code": ..., "details": [...] } }
module JsonResponders
  extend ActiveSupport::Concern

  # Render a successful JSON response.
  #
  # @param data [Object] the serialized payload
  # @param status [Symbol, Integer] HTTP status (default :ok)
  # @param meta [Hash, nil] optional metadata (e.g. pagination)
  def render_success(data = nil, status: :ok, meta: nil)
    body = { success: true, data: data }
    body[:meta] = meta if meta.present?
    render json: body, status: status
  end

  # Render an error JSON response.
  #
  # @param message [String] human-readable error message
  # @param status [Symbol, Integer] HTTP status (default :unprocessable_entity)
  # @param code [String, nil] machine-readable error code
  # @param details [Array, Hash, nil] extra error detail (e.g. validation errors)
  def render_error(message, status: :unprocessable_entity, code: nil, details: nil)
    error = { message: message }
    error[:code] = code if code.present?
    error[:details] = details if details.present?
    render json: { success: false, error: error }, status: status
  end

  # Render a paginated collection using Pagy, attaching pagination metadata.
  #
  # @param pagy [Pagy] the pagy instance from `pagy(scope)`
  # @param data [Object] the serialized records for the current page
  def render_collection(pagy, data, status: :ok)
    render_success(data, status: status, meta: { pagination: pagy_metadata(pagy) })
  end

  private

  def pagy_metadata(pagy)
    {
      page: pagy.page,
      limit: pagy.limit,
      count: pagy.count,
      pages: pagy.pages,
      next: pagy.next,
      prev: pagy.prev
    }
  end
end
