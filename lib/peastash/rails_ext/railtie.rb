require 'peastash/middleware'
require 'active_support/notifications'

class Peastash
  class Railtie < ::Rails::Railtie
    config.peastash = ActiveSupport::OrderedOptions.new

    initializer 'peastash.configure' do |app|
      if app.config.peastash[:enabled]
        Peastash.with_instance.configure!(app.config.peastash)
        ActiveSupport::Notifications.subscribe('process_action.action_controller') do |name, started, finished, unique_id, payload|
          # Handle parameters and sanitize if need be
          payload = data.reject(:db_runtime, :view_runtime)
          payload.merge!(db: data[:db_runtime], view: data[:view_runtime])
          if Peastash.with_instance.configuration[:log_parameters]
            payload[:params].reject { |k, _| ActionController::LogSubscriber::INTERNAL_PARAMS.include?(k) }
          else
            payload.delete(:params)
          end
          # Preserve explicitely set data
          Peastash.with_instance.store.merge!(data) { |key, old_val, new_val| old_val }
        end
        app.config.middleware.use Peastash::Middleware
      end
    end
  end
end
