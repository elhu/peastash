class Buchestache
  class Middleware
    def initialize(app, &custom_block)
      @app = app
      @custom_block = custom_block
    end

    def call(env)
      response = [200, {}, ""]
      Buchestache.log do
        start = Time.now
        response = @app.call(env)
        @custom_block.call(env, response) if @custom_block
        Buchestache.store[:duration] = Time.now - start
        Buchestache.store[:status] = response.first
      end
      response
    end
  end
end
