require 'buchestache/middleware'

class Buchestache
  class Railtie < ::Rails::Railtie
    config.buchestache = ActiveSupport::OrderedOptions.new

    initializer 'buchestache.configure' do |app|
      if app.config.buchestache[:enabled]
        Buchestache.configure!(app.config.buchestache)
        ActiveSupport::Notifications.subscribe('process_action.action_controller') do |name, started, finished, unique_id, data|
          # Handle parameters and sanitize if need be
          if Buchestache.configuration[:log_parameters]
            data[:params].reject! { |k, _| ActionController::LogSubscriber::INTERNAL_PARAMS.include?(k) }
          else
            data.delete(:params)
          end
          # Preserve explicitely set data
          Buchestache.store.merge!(data) { |key, old_val, new_val| old_val }
        end
        app.config.middleware.use Buchestache::Middleware
      end
    end
  end
end
