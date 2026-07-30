# Be sure to restart your server when you modify this file.
#
# Shared Redis connection pool for general application use (caching, rate
# limiting, etc.). Sidekiq manages its own Redis connections separately in
# config/initializers/sidekiq.rb.

REDIS = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
