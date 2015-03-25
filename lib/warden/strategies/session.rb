module Warden
  module Strategies
    class Session < Base
      def valid?
        env['rack.session']
      end

      def authenticate!
        user = user_id ? User.find(user_id) : User.anonymous

        success! user
      end

      def user_id
        Hash(env['rack.session'])['user_id']
      end
    end
  end
end
