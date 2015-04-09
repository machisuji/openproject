#-- encoding: UTF-8
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

# Root class of the API
# This is the place for all API wide configuration, helper methods, exceptions
# rescuing, mounting of differnet API versions etc.

module API
  class Root < Grape::API
    prefix :api

    class Formatter
      def call(object, _env)
        object.respond_to?(:to_json) ? object.to_json : MultiJson.dump(object)
      end
    end

    class Parser
      def call(object, _env)
        MultiJson.load(object)
      rescue MultiJson::ParseError => e
        error = ::API::Errors::ParseError.new(e.message)
        representer = ::API::V3::Errors::ErrorRepresenter.new(error)

        throw :error, status: 400, message: representer.to_json
      end
    end

    http_basic do |username, password|
      basic_auth = Hash(OpenProject::Configuration['api_v3'])['basic_auth']

      # only do stuff if basic auth is configured
      if basic_auth
        # pw matches?
        if username == Hash(basic_auth)['user'] && password == Hash(basic_auth)['password']
          user = User.system
          user.admin = true

          # set user for openproject
          User.current = user

          true
        else
          false
        end
      else
        # we fall back to true as this is the old behaviour
        true
      end
    end

    content_type 'hal+json', 'application/hal+json; charset=utf-8'
    content_type :json,      'application/json; charset=utf-8'
    format 'hal+json'
    formatter 'hal+json', Formatter.new

    parser :json, Parser.new

    helpers do
      def current_user
        if env['rack.session'] && env['rack.session']['user_id']
          user_id = env['rack.session']['user_id']
          User.current = user_id ? User.find(user_id) : User.anonymous
        end

        User.current
      end

      # def warden
      #   env['warden']
      # end

      def authenticate

        #
        # warden.authenticate! # scope: :api_v3
        #
        # User.current = warden.user
        #
        # if Setting.login_required? && (current_user.nil? || (!current_user.admin? && current_user.anonymous?))
        #
        if Setting.login_required? && (current_user.nil? ||  (!current_user.admin? && current_user.anonymous?))
          raise API::Errors::Unauthenticated
        end
      end

      def authorize(permission, context: nil, global: false, user: current_user, &block)
        is_authorized = AuthorizationService.new(permission,
                                                 context: context,
                                                 global: global,
                                                 user: user).call

        return true if is_authorized

        if block_given?
          yield block
        else
          raise API::Errors::Unauthorized
        end

        false
      end

      def authorize_by_with_raise(&_block)
        if yield
          true
        else
          raise API::Errors::Unauthorized
        end
      end

      def running_in_test_env?
        Rails.env.test? && ENV['CAPYBARA_DISABLE_TEST_AUTH_PROTECTION'] != 'true'
      end

      # checks whether the user has
      # any of the provided permission in any of the provided
      # projects
      def authorize_any(permissions, projects: nil, global: false, user: current_user)
        raise ArgumentError if projects.nil? && !global
        projects = Array(projects)

        authorized = permissions.any? do |permission|
          allowed_condition = Project.allowed_to_condition(user, permission)
          allowed_projects = Project.where(allowed_condition)

          if global
            allowed_projects.any?
          else
            !(allowed_projects & projects).empty?
          end
        end

        raise API::Errors::Unauthorized unless authorized
        authorized
      end
    end

    rescue_from ActiveRecord::RecordNotFound do
      api_error = ::API::Errors::NotFound.new
      representer = ::API::V3::Errors::ErrorRepresenter.new(api_error)
      env['api.format'] = 'hal+json'
      error_response(status: api_error.code, message: representer.to_json)
    end

    rescue_from ActiveRecord::StaleObjectError do
      api_error = ::API::Errors::Conflict.new
      representer = ::API::V3::Errors::ErrorRepresenter.new(api_error)
      env['api.format'] = 'hal+json'
      error_response(status: api_error.code, message: representer.to_json)
    end

    rescue_from ::API::Errors::ErrorBase, rescue_subclasses: true do |e|
      representer = ::API::V3::Errors::ErrorRepresenter.new(e)
      env['api.format'] = 'hal+json'
      error_response(status: e.code, message: representer.to_json)
    end

    # run authentication before each request
    before do
      current_user
      authenticate
    end

    version 'v3', using: :path do
      mount API::V3::Root
    end
  end
end
