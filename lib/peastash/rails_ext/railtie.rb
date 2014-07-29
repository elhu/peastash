require 'peastash/middleware'
require 'active_support/notifications'

class Peastash
  class Railtie < ::Rails::Railtie
    config.peastash = ActiveSupport::OrderedOptions.new

    initializer 'peastash.configure' do |app|
      if app.config.peastash[:enabled]
        Peastash.with_instance.configure!(app.config.peastash)
        ActiveSupport::Notifications.subscribe('process_action.action_controller') do |name, started, finished, unique_id, data|
          # Handle parameters and sanitize if need be
          to_reject = [:db_runtime, :view_runtime, :exception]
          payload = data.reject { |key, _| to_reject.include?(key) }
          payload.merge!(db: data[:db_runtime], view: data[:view_runtime])
          payload.merge!(exception: { class: data[:exception].first, message: data[:exception].last }) if data.has_key?(:exception)
          if Peastash.with_instance.configuration[:log_parameters]
            payload[:params].reject { |k, _| ActionController::LogSubscriber::INTERNAL_PARAMS.include?(k) }
          else
            payload.delete(:params)
          end
          # Preserve explicitely set data
          Peastash.with_instance.store.merge!(payload) { |key, old_val, new_val| old_val }
        end
        before_middleware = app.config.peastash[:insert_before] || ActionDispatch::ShowExceptions
        app.config.middleware.insert_before before_middleware, Peastash::Middleware
      end
    end
  end
end
