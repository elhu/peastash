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
        @before_block.call(env, response) if @before_block

        response = @app.call(env)

        Buchestache.store[:duration] = Time.now - start
        Buchestache.store[:status] = response.first

        @after_block.call(env, response) if @after_block
      end
      response
    end
  end
end
