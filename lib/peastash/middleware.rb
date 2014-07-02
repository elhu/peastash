require 'socket'

class Peastash
  class Middleware
    def initialize(app, before_block = nil, after_block = nil)
      @app = app
      define_singleton_method(:before_block, before_block || ->(_, _) {})
      define_singleton_method(:after_block, after_block || ->(_, _) {})
    end

    def call(env)
      response = nil
      Peastash.with_instance.log do
        start = Time.now

        safe_call { before_block(env, response) }

        # Setting this before calling the next middleware so it can be overriden
        request = Rack::Request.new(env)
        Peastash.with_instance.store[:ip] = request.ip

        response = @app.call(env)

        Peastash.with_instance.store[:duration] = ((Time.now - start) * 1000.0).round(2)
        Peastash.with_instance.store[:status] = response.first

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
