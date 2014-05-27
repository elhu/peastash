require 'spec_helper'
require 'buchestache/middleware'

describe Buchestache::Middleware do
  let(:app) { ->(env) { [200, {}, "app"] } }
  let(:before_block) { ->(env, response) {  } }
  let(:after_block) { ->(env, response) {  } }

  let(:middleware) do
    Buchestache::Middleware.new(app, before_block, after_block)
  end

  describe "Rack middleware" do
    it "wraps the call to the next middleware in a Buchestache block" do
      expect(Buchestache).to receive(:log)
      middleware.call env_for('/')
    end

    it "doesn't interrupt the middleware chain" do
      expect(app).to receive(:call).and_call_original
      middleware.call env_for('/')
    end

    it "calls whatever block is given to the middleware" do
      expect(before_block).to receive(:call)
      expect(after_block).to receive(:call)
      code, env = middleware.call env_for('/')
    end

    context 'storing data in the custom block' do
      before :each do
        block = ->(env, response) {
          request = Rack::Request.new(env)
          Buchestache.store[:path] = request.path
        }
        @middleware = Buchestache::Middleware.new(app, block)
      end

      it "can store arbitrary data in the Buchestache store" do
        @middleware.call env_for('/')
        expect(Buchestache.store[:path]).to eq('/')
      end

      it 'uses the stored data to build the event' do
        expect(LogStash::Event).to receive(:new).with({
          '@source' => Buchestache::STORE_NAME,
          '@fields' => { path: '/', duration: 0, status: 200 },
          '@tags' => []
        })
        Timecop.freeze { @middleware.call env_for('/') }
      end
    end

    context 'storing data in the rack app' do
      before :each do
        app = ->(env) do
          request = Rack::Request.new(env)
          Buchestache.store[:scheme] = request.scheme
          [200, {}, "app"]
        end
        @middleware = Buchestache::Middleware.new(app, before_block)
      end

      it "can store arbitrary data in the Buchestache store" do
        @middleware.call env_for('/')
        expect(Buchestache.store[:scheme]).to eq('http')
      end

      it 'uses the stored data to build the event' do
        expect(LogStash::Event).to receive(:new).with({
          '@source' => Buchestache::STORE_NAME,
          '@fields' => { scheme: 'http', duration: 0, status: 200 },
          '@tags' => []
        })
        Timecop.freeze { @middleware.call env_for('/') }
      end
    end

    context 'without a custom block' do
      it "doesn't try to call the block" do
        @middleware = Buchestache::Middleware.new(app)
        expect {
          @middleware.call env_for('/')
        }.to_not raise_error
      end
    end

    context 'persistence between before/after block' do
      it "saves instance variables between before/after block" do
        before_block = ->(env, request) { @foo = 'foo' }
        after_block = ->(env, request) { Buchestache.store[:foo] = @foo }
        @middleware = Buchestache::Middleware.new(app, before_block, after_block)

        expect(LogStash::Event).to receive(:new).with({
          '@source' => Buchestache::STORE_NAME,
          '@fields' => { duration: 0, status: 200, foo: 'foo' },
          '@tags' => []
        })
        Timecop.freeze { @middleware.call env_for('/') }
      end
    end

  end

  def env_for(url, opts={})
    Rack::MockRequest.env_for(url, opts)
  end
end
