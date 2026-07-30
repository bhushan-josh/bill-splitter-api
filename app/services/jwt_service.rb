# frozen_string_literal: true

require "jwt"

# Encodes and decodes JSON Web Tokens used for stateless authentication.
#
#   token   = JwtService.encode(user_id: user.id)
#   payload = JwtService.decode(token) # => { "user_id" => 1, "exp" => ... }
#
# Raises JwtService::InvalidToken when a token is malformed, tampered with, or
# expired, so callers can rescue a single, framework-agnostic error type.
class JwtService
  class InvalidToken < StandardError; end

  ALGORITHM = "HS256"
  DEFAULT_EXPIRY = 24.hours

  class << self
    # @param payload [Hash] claims to embed (e.g. { user_id: 1 })
    # @param exp [ActiveSupport::Duration] time-to-live from now
    # @return [String] the signed JWT
    def encode(payload, exp: DEFAULT_EXPIRY)
      claims = payload.dup
      claims[:exp] = exp.from_now.to_i
      JWT.encode(claims, secret_key, ALGORITHM)
    end

    # @param token [String] a signed JWT
    # @return [HashWithIndifferentAccess] the decoded claims
    # @raise [InvalidToken] if the token is invalid or expired
    def decode(token)
      payload, = JWT.decode(token, secret_key, true, { algorithm: ALGORITHM })
      payload.with_indifferent_access
    rescue JWT::DecodeError, JWT::ExpiredSignature => e
      raise InvalidToken, e.message
    end

    private

    def secret_key
      key = ENV["JWT_SECRET_KEY"].presence || Rails.application.secret_key_base
      raise InvalidToken, "JWT secret key is not configured" if key.blank?

      key
    end
  end
end
