require_relative 'boot'
require 'dotenv'
require 'rails/all'

# Workaround to avoid the "Celluloid is not yet started; use Celluloid.boot" error
# with Celluloid 0.17.4 https://github.com/endofunky/sidetiq/issues/160
require 'celluloid'
Celluloid.boot
require 'sidetiq'

Dotenv.overload('.env', ".env.#{Rails.env}").tap do |env|
  if env.empty?
    fail 'Cannot run Supermarket without a .env file.'
  end
end

%w[
  active_record
  action_controller
  action_mailer
  sprockets
].each do |framework|
  begin
    require "#{framework}/railtie"
  rescue LoadError
    Rails.logger.info "Unable to load #{framework}."
  end
end

require_relative '../app/lib/supermarket/host'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Supermarket
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Include vendor fonts in the asset pipeline
    config.assets.paths << Rails.root.join('vendor', 'assets', 'fonts')

    # Include vendor images in the asset pipeline
    config.assets.paths << Rails.root.join('vendor', 'assets', 'images')

    # Ensure fonts and images are precompiled during asset compilation
    config.assets.precompile += %w[*.svg *.eot *.woff *.ttf *.gif *.png]

    # Ensurer mailer assets are precompiled during asset compilation
    config.assets.precompile += %w[mailers.css]

    # Use a custom exception handling application
    config.exceptions_app = proc do |env|
      ExceptionsController.action(:show).call(env)
    end

    # Define the status codes for rescuing our custom exceptions
    config.action_dispatch.rescue_responses.merge!(
      'Supermarket::Authorization::NoAuthorizerError'  => :not_implemented,
      'Supermarket::Authorization::NotAuthorizedError' => :unauthorized
    )

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'
    config.active_record.default_timezone = :utc

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Skip locale validation.
    # Note: if the time comes to support locales, this will want to be set to
    # true.
    config.i18n.enforce_available_locales = false

    # Set default URL for ActionMailer
    config.action_mailer.default_url_options = {
      host: ENV['FQDN'],
      port: ENV['PORT'],
      protocol: ENV['PROTOCOL']
    }

    config.action_mailer.asset_host = Supermarket::Host.full_url

    # Set default from email for ActionMailer
    ActionMailer::Base.default from: ENV['FROM_EMAIL']
  end
end
