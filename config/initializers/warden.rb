require 'warden/strategies/basic_auth'

Warden::Strategies.add :basic_auth, Warden::Strategies::BasicAuth
Warden::Strategies.add :session, Warden::Strategies::Session
