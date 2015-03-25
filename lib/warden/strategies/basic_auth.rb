module Warden
  module Strategies
    class BasicAuth < Base
      def auth
        @auth ||= Rack::Auth::Basic::Request.new(env)
      end

      def valid?
        config && auth.provided? && auth.basic? && auth.credentials
      end

      def authenticate!
        if username == config['user'] && password == config['password']
          user = User.system
          user.admin = true
          success! user
        else
          headers 'WWW-Authenticate' => %(Basic realm="realm")
          fail! 'wrong user and/or password'
        end
      end

      def store?
        false # don't store user in session
      end

      def username
        auth.credentials.first
      end

      def password
        auth.credentials.last
      end

      def config
        Hash(OpenProject::Configuration['api_v3'])['master_account']
      end
    end
  end
end
