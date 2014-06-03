class Buchestache
  module Watch
    def watch(event, opts = {}, &block)
      event_group = opts[:event_group] || event
      ActiveSupport::Notifications.subscribe(event) do |*args|
        # Calling the processing block with the Notification args and the store
        block.call(*args, Buchestache.store[event_group])
      end
    end
  end
end

Buchestache.send :extend, Buchestache::Watch
