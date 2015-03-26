module OpenProject
  module Authentication
    class Manager < Warden::Manager
      def self.strategies
        @strategies ||= begin
          hash = {
            api_v3: [:basic_auth, :session]
          }

          hash.tap do |h|
            h.default = []
          end
        end
      end

      def self.register_strategy(name, clazz, scopes)
        Warden::Strategies.add name, clazz

        scopes.each do |scope|
          strategies[scope] << name
        end
      end

      def self.configure(config)
        config.default_strategies :basic_auth, :session
        config.failure_app = lambda { |env| [401, {}, ['unauthorized']] }

        config.scope_defaults :api_v3, strategies: strategies[:api_v3], store: false
      end
    end
  end
end
