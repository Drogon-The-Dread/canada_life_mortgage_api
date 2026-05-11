class SwaggerAuthMiddleware
  SWAGGER_PATH_PREFIX = "/api-docs"

  def initialize(app)
    @app  = app
    @auth = Rack::Auth::Basic.new(app, "Mortgage API Docs") do |user, pass|
      expected_user = ENV.fetch("SWAGGER_USERNAME", "swagger")
      expected_pass = ENV.fetch("SWAGGER_PASSWORD", "changeme")
      ActiveSupport::SecurityUtils.secure_compare(user, expected_user) &&
        ActiveSupport::SecurityUtils.secure_compare(pass, expected_pass)
    end
  end

  def call(env)
    env["PATH_INFO"].start_with?(SWAGGER_PATH_PREFIX) ? @auth.call(env) : @app.call(env)
  end
end
