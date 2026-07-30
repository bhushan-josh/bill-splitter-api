# frozen_string_literal: true

require "sidekiq/web"

Rails.application.routes.draw do
  # Sidekiq dashboard. Lock this down (authentication) before exposing it in
  # production.
  mount Sidekiq::Web => "/sidekiq"

  # Rails' built-in liveness check: returns 200 if the app boots cleanly.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # GET /api/v1/health
      get "health", to: "health#show"
    end
  end

  # Catch-all: any unmatched route returns the standard JSON error envelope
  # instead of Rails' default HTML/debug error page. Keep this last.
  match "*unmatched", to: "application#route_not_found", via: :all
end
