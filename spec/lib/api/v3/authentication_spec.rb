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

require 'spec_helper'

describe API::V3, type: :request do

  before do
    Setting.login_required = 1
  end

  before do
    api_v3 = {
      'basic_auth' => {
        'user' => 'root',
        'password' => 'toor'
      }
    }
    OpenProject::Configuration['api_v3'] = api_v3
  end

  def basic_auth(user, password)
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials user, password
    {'HTTP_AUTHORIZATION' => credentials}
  end

  describe 'session' do
    let(:user) { FactoryGirl.create :user }

    context 'web' do
      it 'redirects unless logged in' do
        get '/my/page'
        expect(response.status).to eq 302
      end

      it 'shows page when logged in' do
        as_logged_in_user(user) do
          get '/my/page'
        end
        expect(response.status).to eq 200
      end
    end

    context 'api' do
      let(:resource) { "/api/v3/users/#{user.id}"}

      it 'refuses request without a session' do
        get resource
        expect(response.status).to eq 401
      end

      # allow api requests via session without basic auth
      xit 'serves the request when logged in' do
        as_logged_in_user(user) do
          get resource
        end
        expect(response.status).to eq 200
      end

      # no session

      context 'basic auth provided without session' do
        it 'wrong creds' do
          get resource, {}, basic_auth('root', 'wrrong')
          expect(response.status).to eq 401
        end

        it 'correct creds' do
          get resource, {}, basic_auth('root', 'toor')
          expect(response.status).to eq 200
          expect(User.current).to eq User.system # wichtig
        end
      end

      # without session

      context 'basic auth provided with session' do
        it 'wrong creds' do
          as_logged_in_user(user) do
            get resource, {}, basic_auth('root', 'wrrong')
          end

          expect(response.status).to eq 401
        end

        # todo, returns bob user, statt system
        xit 'correct creds' do
          as_logged_in_user(user) do
            get resource, {}, basic_auth('root', 'toor')
          end

          expect(response.status).to eq 200
          expect(User.current).to eq User.system # wichtig
          expect(request.env['warden'].user).to eq User.system # wichtig
        end
      end
    end
  end

  describe 'basic auth' do

    # register basic auth strategy

    let(:user) { FactoryGirl.create :user }
    let(:resource) { "/api/v3/users/#{user.id}"}

    def basic_auth(user, password)
      credentials = ActionController::HttpAuthentication::Basic.encode_credentials user, password
      {'HTTP_AUTHORIZATION' => credentials}
    end

    before do
      Setting.login_required = 1
    end

    context 'without credentials' do
      before do
        get resource
      end

      it 'should return 401 unauthorized' do
        expect(response.status).to eq 401
      end
    end

    context 'with credentials' do
      before do
        api_v3 = {
          'basic_auth' => {
            'user' => 'root',
            'password' => 'toor'
          }
        }
        OpenProject::Configuration['api_v3'] = api_v3
      end

      context 'with invalid credentials' do
        before do
          get resource, {}, basic_auth('hans', 'wrongpassword')
        end

        it 'should return 401 unauthorized' do
          expect(response.status).to eq 401
        end
      end

      context 'with valid credentials' do
        before do
          get resource, {}, basic_auth('root', 'toor')
        end

        it 'should return 200 OK' do
          expect(response.status).to eq 200
        end
      end
    end

    context 'missing config' do
      before do
        OpenProject::Configuration['api_v3'] = nil
      end

      it 'refuses request without a session' do
        get resource
        expect(response.status).to eq 401
      end

      # allow api requests via session without basic auth
      xit 'serves the request when logged in' do
        as_logged_in_user(user) do
          get resource
        end
        expect(response.status).to eq 200
      end
    end
  end
end
