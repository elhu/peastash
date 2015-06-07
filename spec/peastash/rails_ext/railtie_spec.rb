require 'spec_helper'
require 'rails'
require 'peastash/rails_ext'
require 'simplecov'

describe Peastash::Railtie do
  context 'not configured' do
    it "doesn't add the middleware by default" do
      run_with_env 'test_without_peastash' do
        expect(Rails.application.middleware).to_not include(Peastash::Middleware)
      end
    end

    it "doesn't add the subscriber" do
      run_with_env 'test_without_peastash' do
        Peastash.with_instance.store.clear
        ActiveSupport::Notifications.instrument('process_action.action_controller', db_runtime: 1)
        expect(Peastash.with_instance.store).to_not include(db: 1)
      end
    end
  end

  context 'correctly configured' do
    context 'with specific conf' do
      it 'places the middleware before the configured middleware if specified' do
        run_with_env 'test_with_specific_position' do
          cookies_index = -1
          Rails.application.middleware.each_with_index { |middleware, index| cookies_index = index if middleware == ActionDispatch::Cookies }
          expect(Rails.application.middleware[cookies_index - 1]).to eq(Peastash::Middleware)
        end
      end
    end

    context 'with regular conf' do
      before :all do
        ENV['RAILS_ENV'] = 'test'
        require testing_rails_32? ? 'dummy-3.2/config/environment' : 'dummy/config/environment'
      end

      before(:each) { Peastash.with_instance.store.clear }

      context 'middleware' do
        it "adds the middleware" do
          expect(Rails.application.middleware).to include(Peastash::Middleware)
        end

        it 'adds the middleware before ActionDispatch::ShowExceptions by default' do
          show_exceptions_index = -1
          Rails.application.middleware.each_with_index { |middleware, index| show_exceptions_index = index middleware == ActionDispatch::ShowExceptions }
          expect(Rails.application.middleware[show_exceptions_index - 1]).to eq(Peastash::Middleware)
        end
      end

      it "adds a subscriber on 'process_action.action_controller' to gather metrics about the request" do
        ActiveSupport::Notifications.instrument('process_action.action_controller', db_runtime: 1)
        expect(Peastash.with_instance.store).to include(db: 1)
      end

      context "params logging" do
        it "doesn't log the parameters if log_parameters isn't true" do
          Peastash.with_instance.configuration[:log_parameters] = false
          perform_request('/')
          expect(Peastash.with_instance.store.keys).to_not include(:params)
        end

        it "logs the parameters if log_parameters is true" do
          Peastash.with_instance.configuration[:log_parameters] = true
          perform_request('/')
          expect(Peastash.with_instance.store.keys).to include(:params)
        end

        it "doesn't log filtered parameters in clear text" do
          Peastash.with_instance.configuration[:log_parameters] = true
          perform_request('/?password=foo')
          expect(Peastash.with_instance.store[:params]["password"]).to eq("[FILTERED]")
        end
      end unless Rails.version.start_with?('3.') # The actual railtie work, just not in the specs for now
    end
  end
end

def perform_request(path)
  (Rails.application.call env_for(path)).tap do |res|
    # Rack-Lock doesn't release the mutex if body is not closed
    res[2].close unless testing_rails_32?
  end
end

def run_with_env(env = 'test')
  # Can't run those tests on jruby... yet
  return if RUBY_PLATFORM == 'java'
  fork do
    SimpleCov.running = false
    ENV['RAILS_ENV'] = env
    if testing_rails_32?
      require 'dummy-3.2/config/environment'
    else
      require 'dummy/config/environment'
    end
    yield
  end
end

def testing_rails_32?
  Rails.version.start_with?('3.')
end
