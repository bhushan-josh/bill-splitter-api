# frozen_string_literal: true

# Resolves the authenticated user for the current request from the
# `Authorization: Bearer <token>` header and memoizes it. This concern only
# *reads* the token — it never halts the request; enforcement lives in the
# Authentication concern.
module CurrentUser
  extend ActiveSupport::Concern

  private

  # @return [User, nil] the authenticated user, or nil if the request carries
  #   no valid token.
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = resolve_current_user
  end

  def signed_in?
    current_user.present?
  end

  def resolve_current_user
    token = bearer_token
    return nil if token.blank?

    payload = JwtService.decode(token)
    User.find_by(id: payload[:user_id])
  rescue JwtService::InvalidToken
    nil
  end

  def bearer_token
    header = request.authorization || request.headers["Authorization"]
    return nil if header.blank?

    header.to_s.split.last
  end
end
