# Be sure to restart your server when you modify this file.
#
# Cross-Origin Resource Sharing (CORS) configuration so the API can be called
# from browser-based frontends. Allowed origins are driven by the
# CORS_ORIGINS environment variable (comma-separated). Defaults to "*" in
# development for convenience.
#
# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(ENV.fetch("CORS_ORIGINS", "*").split(",").map(&:strip))

    resource "*",
             headers: :any,
             expose: %w[Authorization],
             methods: %i[get post put patch delete options head],
             max_age: 600
  end
end
