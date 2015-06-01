#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2015 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

module OpenProject
  module OmniAuth
    # This is a copy of the default OmniAuth FailureEndpoint
    # minus the raise_out! we don't want and plus the actual error message
    # as opposed to always just 'missing_code'.
    class FailureEndpoint
      attr_reader :env

      def self.call(env)
        new(env).call
      end

      def initialize(env)
        @env = env
      end

      def call
        redirect_to_failure
      end

      def error
        env['omniauth.error'] || ::OmniAuth::Error.new(env['omniauth.error.type'])
      end

      def redirect_to_failure
        message = Rack::Utils.escape error.message
        new_path = "
          #{env['SCRIPT_NAME']}#{::OmniAuth.config.path_prefix}/failure?
          message=#{message}
          #{origin_query_param}
          #{strategy_name_query_param}
        "

        Rack::Response.new(['302 Moved'], 302, 'Location' => new_path.gsub(/\s+/, '')).finish
      end

      def strategy_name_query_param
        return '' unless env['omniauth.error.strategy']
        "&strategy=#{env['omniauth.error.strategy'].name}"
      end

      def origin_query_param
        return '' unless env['omniauth.origin']
        "&origin=#{Rack::Utils.escape(env['omniauth.origin'])}"
      end
    end
  end
end
