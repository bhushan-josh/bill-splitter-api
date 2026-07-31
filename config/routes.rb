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

      # Authentication
      post "signup", to: "auth#signup"
      post "login", to: "auth#login"
      get "me", to: "me#show"

      # User search
      get "users/search", to: "users#search"

      # Friend requests
      resources :friend_requests, only: %i[create destroy] do
        member do
          patch :accept
          patch :reject
        end
      end

      # Friends
      resources :friends, only: %i[index destroy], controller: "friendships"

      # Expenses
      resources :expenses, only: %i[show create update destroy]

      # Settlements (payments that pay down debt; change balances immediately)
      resources :settlements, only: %i[create update destroy]

      # Chat messages (friend or group; text only)
      resources :messages, only: %i[index create]

      # Notifications
      resources :notifications, only: :index do
        member do
          patch :read
        end
      end

      # Balances (derived on demand; nothing is stored)
      get "balances/friends", to: "balances#friends"
      get "balances/groups", to: "balances#groups"
      get "balances/overall", to: "balances#overall"

      # Groups
      resources :groups do
        member do
          post :leave
          post :transfer_owner
          post "members", action: :add_member
          delete "members/:user_id", action: :remove_member, as: :member
        end
      end
    end
  end

  # Catch-all: any unmatched route returns the standard JSON error envelope
  # instead of Rails' default HTML/debug error page. Keep this last.
  match "*unmatched", to: "application#route_not_found", via: :all
end
