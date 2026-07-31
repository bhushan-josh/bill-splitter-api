# frozen_string_literal: true

require "sidekiq/web"

# Protect the Sidekiq web dashboard (mounted at /sidekiq in config/routes.rb)
# with HTTP Basic auth. Credentials are read from the environment so they are
# never committed to source control.
#
#   * When both SIDEKIQ_WEB_USERNAME and SIDEKIQ_WEB_PASSWORD are set, the
#     dashboard requires those credentials everywhere.
#   * When they are unset, the dashboard is open in local development/test for
#     convenience but locked down (rejects every request) in production, so an
#     unconfigured production deploy never exposes it.
Sidekiq::Web.use(Rack::Auth::Basic, "Sidekiq") do |username, password|
  expected_username = ENV["SIDEKIQ_WEB_USERNAME"].to_s
  expected_password = ENV["SIDEKIQ_WEB_PASSWORD"].to_s

  if expected_username.present? && expected_password.present?
    # Constant-time comparison avoids leaking credential length/content via
    # timing. `&` (not `&&`) keeps both comparisons unconditional.
    ActiveSupport::SecurityUtils.secure_compare(username, expected_username) &
      ActiveSupport::SecurityUtils.secure_compare(password, expected_password)
  else
    !Rails.env.production?
  end
end
