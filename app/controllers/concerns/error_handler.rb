# frozen_string_literal: true

# Centralized exception handling for the API. Rescued exceptions are rendered
# through the consistent JSON error envelope provided by JsonResponders.
#
# Add new `rescue_from` clauses here as the application grows so that error
# formatting stays in one place.
module ErrorHandler
  extend ActiveSupport::Concern

  included do
    # Order matters: more specific rescues should be declared last, since
    # Rails evaluates rescue_from handlers bottom-up.
    rescue_from StandardError, with: :handle_internal_error unless Rails.env.local?
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

    # Pundit is required lazily so this concern does not hard-depend on it.
    rescue_from Pundit::NotAuthorizedError, with: :handle_not_authorized if defined?(Pundit)
  end

  private

  def handle_not_found(exception)
    render_error(exception.message, status: :not_found, code: "not_found")
  end

  def handle_record_invalid(exception)
    render_error(
      "Validation failed",
      status: :unprocessable_entity,
      code: "record_invalid",
      details: exception.record&.errors&.full_messages
    )
  end

  def handle_parameter_missing(exception)
    render_error(exception.message, status: :bad_request, code: "parameter_missing")
  end

  def handle_not_authorized(_exception)
    render_error("You are not authorized to perform this action", status: :forbidden, code: "forbidden")
  end

  def handle_internal_error(exception)
    Rails.logger.error("#{exception.class}: #{exception.message}")
    Rails.logger.error(exception.backtrace&.join("\n"))
    render_error("Something went wrong", status: :internal_server_error, code: "internal_server_error")
  end
end
