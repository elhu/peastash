require 'socket'

class Buchestache
  class Middleware
    def initialize(app, before_block = nil, after_block = nil)
      @app = app
      define_singleton_method(:before_block, before_block || ->(_, _) {})
      define_singleton_method(:after_block, after_block || ->(_, _) {})
    end

    def call(env)
      response = nil
      Buchestache.log do
        start = Time.now
        @hostname ||= Socket.gethostname

        safe_call { before_block(env, response) }

        response = @app.call(env)

        Buchestache.store[:duration] = Time.now - start
        Buchestache.store[:status] = response.first
        Buchestache.store[:hostname] = @hostname

        safe_call { after_block(env, response) }
      end
      response
    end

    private
    def safe_call
      yield
    rescue StandardError => e
      STDERR.puts e
    end
  end
end
