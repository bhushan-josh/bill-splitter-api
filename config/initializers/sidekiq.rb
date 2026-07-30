# Be sure to restart your server when you modify this file.
#
# Sidekiq background-job processor configuration. Both the client (Rails
# process enqueuing jobs) and the server (Sidekiq worker process) are pointed
# at the same Redis instance via REDIS_URL.

redis_config = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
