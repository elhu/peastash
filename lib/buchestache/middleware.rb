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
        if @before_block
          @before_block.call(env, response) rescue nil
        end

        response = @app.call(env)

        Buchestache.store[:duration] = Time.now - start
        Buchestache.store[:status] = response.first

        if @after_block
          @after_block.call(env, response) rescue nil
        end
      end
      response
    end
  end
end
