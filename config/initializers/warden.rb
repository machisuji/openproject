# require 'warden'
# require 'open_project/authentication/manager'
#
# Rails.configuration.middleware.use Warden::Manager do |config|
#   OpenProject::Authentication::Manager.configure(config)
# end
#
# require 'warden/strategies/basic_auth'
# require 'warden/strategies/session'
#
# Warden::Strategies.add :basic_auth, Warden::Strategies::BasicAuth
# Warden::Strategies.add :session, Warden::Strategies::Session
