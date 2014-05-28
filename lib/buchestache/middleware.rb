require 'socket'

class Buchestache
  class Middleware
    def initialize(app, before_block = nil, after_block = nil)
      @app = app
      @before_block = before_block
      @after_block = after_block
    end

    def call(env)
      response = [200, {}, Rack::Response.new]
      Buchestache.log do
        start = Time.now
        @hostname ||= Socket.gethostname

        if @before_block
          begin
            @before_block.call(env, response)
          rescue StandardError => e
            STDERR.puts e
          end
        end

        response = @app.call(env)

        Buchestache.store[:duration] = Time.now - start
        Buchestache.store[:status] = response.first
        Buchestache.store[:hostname] = @hostname

        if @after_block
          begin
            @after_block.call(env, response)
          rescue StandardError => e
            STDERR.puts e
          end
        end
      end
      response
    end
  end
end
