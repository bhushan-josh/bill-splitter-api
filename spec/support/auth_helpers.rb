# frozen_string_literal: true

module AuthHelpers
  # Build an Authorization header carrying a valid JWT for the given user.
  def auth_headers(user)
    { "Authorization" => "Bearer #{JwtService.encode({ user_id: user.id })}" }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
