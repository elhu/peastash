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

        Peastash.safely do
          before_block(env, response)

          # Setting this before calling the next middleware so it can be overriden
          request = Rack::Request.new(env)
          if env.has_key? 'HTTP_X_REQUEST_START'
            Peastash.with_instance.store[:time_in_queue] = ((Time.now.to_f - env['HTTP_X_REQUEST_START'].to_f) * 1000.0).round(2)
          end
          Peastash.with_instance.store[:ip] = request.ip
        end

        response = @app.call(env)

        Peastash.safely do
          Peastash.with_instance.store[:duration] = ((Time.now - start) * 1000.0).round(2)
          Peastash.with_instance.store[:status] = response.first

          after_block(env, response)
        end
      end

      response
    end
  end
end
