# frozen_string_literal: true

module Api
  module V1
    # Lightweight liveness/readiness endpoint. Reports the status of the app
    # and its critical backing services (PostgreSQL and Redis) so load
    # balancers and uptime monitors can verify the API is healthy.
    class HealthController < BaseController
      skip_before_action :authenticate_user!

      def show
        render_success(
          {
            status: "ok",
            service: "billsplitter-api",
            version: "v1",
            time: Time.current.iso8601,
            dependencies: {
              database: database_status,
              redis: redis_status
            }
          }
        )
      end

      private

      def database_status
        ActiveRecord::Base.connection.execute("SELECT 1")
        "ok"
      rescue StandardError
        "unavailable"
      end

      def redis_status
        REDIS.ping == "PONG" ? "ok" : "unavailable"
      rescue StandardError
        "unavailable"
      end
    end
  end
end
