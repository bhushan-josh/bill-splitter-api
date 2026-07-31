# frozen_string_literal: true

source "https://rubygems.org"

ruby "3.2.0"

# Rails (API-only)
gem "rails", "8.1.3"

# PostgreSQL database adapter
gem "pg", "~> 1.5"

# Puma web server
gem "puma", ">= 5.0"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

# --- Background processing -------------------------------------------------
# Sidekiq background job processor (backed by Redis)
gem "sidekiq", "~> 7.3"
# Redis client (shared cache / Sidekiq backend)
gem "redis", "~> 5.3"

# --- API & auth ------------------------------------------------------------
# JSON Web Token encoding/decoding (authentication implemented later)
gem "jwt", "~> 2.9"
# Password hashing for has_secure_password (models added later)
gem "bcrypt", "~> 3.1.7"
# Authorization policies
gem "pundit", "~> 2.4"
# Pagination
gem "pagy", "~> 9.3"

# Cross-Origin Resource Sharing
gem "rack-cors", "~> 2.0"

# Load environment variables from .env files
gem "dotenv-rails", "~> 3.1"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  # RSpec test framework
  gem "rspec-rails", "~> 7.1"
  # Factory-based test fixtures
  gem "factory_bot_rails", "~> 6.4"
  # Fake data generation for specs/factories
  gem "faker", "~> 3.5"

  # Ruby style / lint
  gem "rubocop", "~> 1.71", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false
end

group :test do
  # One-liner matchers for common Rails functionality
  gem "shoulda-matchers", "~> 6.4"
  # Clean the database between test runs
  gem "database_cleaner-active_record", "~> 2.2"
end
