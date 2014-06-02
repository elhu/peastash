require 'rails'
require 'buchestache/rails_ext'

describe Buchestache::Railtie do
  context 'not configured' do
    it "doesn't add the middleware by default" do
      run_with_env 'test_without_buchestache' do
        expect(Rails.application.middleware).to_not include(Buchestache::Middleware)
      end
    end

    it "doesn't add the subscriber" do
      run_with_env 'test_without_buchestache' do
        Buchestache.store.clear
        ActiveSupport::Notifications.instrument('process_action.action_controller', db_runtime: 1)
        expect(Buchestache.store).to_not include(db_runtime: 1)
      end
    end
  end

  context 'correctly configured' do
    before :all do
      require 'dummy/config/environment'
    end

    it "adds the middleware" do
      expect(Rails.application.middleware).to include(Buchestache::Middleware)
    end

    it "adds a subscriber on 'process_action.action_controller' to gather metrics about the request" do
      Buchestache.store.clear
      ActiveSupport::Notifications.instrument('process_action.action_controller', db_runtime: 1)
      expect(Buchestache.store).to include(db_runtime: 1)
    end
  end
end

def run_with_env(env = 'test', &block)
  fork do
    SimpleCov.running = false
    ENV['RAILS_ENV'] = env
    require 'dummy/config/environment'
    yield
  end
end
