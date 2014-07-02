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
    before :all do
      ENV['RAILS_ENV'] = 'test'
      require 'dummy/config/environment'
    end

    before(:each) { Peastash.with_instance.store.clear }

    it "adds the middleware" do
      expect(Rails.application.middleware).to include(Peastash::Middleware)
    end

    it "adds a subscriber on 'process_action.action_controller' to gather metrics about the request" do
      ActiveSupport::Notifications.instrument('process_action.action_controller', db_runtime: 1)
      expect(Peastash.with_instance.store).to include(db: 1)
    end

    context "params logging" do
      it "doesn't log the parameters if log_parameters isn't true" do
        Peastash.with_instance.configuration[:log_parameters] = false
        Rails.application.call env_for('/')
        expect(Peastash.with_instance.store.keys).to_not include(:params)
      end

      it "logs the parameters if log_parameters is true" do
        Peastash.with_instance.configuration[:log_parameters] = true
        Rails.application.call env_for('/')
        expect(Peastash.with_instance.store.keys).to include(:params)
      end

      it "doesn't log filtered parameters in clear text" do
        Peastash.with_instance.configuration[:log_parameters] = true
        Rails.application.call env_for('/?password=foo')
        expect(Peastash.with_instance.store[:params]["password"]).to eq("[FILTERED]")
      end
    end
  end
end

def run_with_env(env = 'test')
  # Can't run those tests on jruby... yet
  return if RUBY_PLATFORM == 'java'
  fork do
    SimpleCov.running = false
    ENV['RAILS_ENV'] = env
    require 'dummy/config/environment'
    yield
  end
end
