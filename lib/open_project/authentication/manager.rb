module OpenProject
  module Authentication
    class Manager < Warden::Manager
      serialize_into_session do |user|
        user.id
      end

      serialize_from_session do |id|
        User.find id
      end

      def initialize(app, options = {}, &configure)
        block = lambda do |config|
          self.class.configure config

          configure.call config if configure
        end

        super app, options, &block
      end

      class << self
        def scope_strategies
          @scope_strategies ||= {}
        end

        def store_defaults
          @store_defaults ||= Hash.new false
        end

        def configure(config)
          config.default_strategies :session
          config.failure_app = OpenProject::Authentication::FailureApp.new
          config.intercept_401 = false

          scope_strategies.each do |scope, strategies|
            config.scope_defaults scope, strategies: strategies, store: store_defaults[scope]
          end
        end
      end
    end
  end
end
