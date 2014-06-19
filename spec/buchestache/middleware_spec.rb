require 'spec_helper'
require 'buchestache/middleware'
require 'pry'

describe Buchestache::Middleware do
  before { Socket.stub(:gethostname) { 'example.com' } }
  let(:app) { ->(env) { [200, {}, "app"] } }
  let(:before_block) { ->(env, response) {} }
  let(:after_block) { ->(env, response) {} }

  let(:middleware) do
    Buchestache::Middleware.new(app, before_block, after_block)
  end

  describe "Rack middleware" do
    it "wraps the call to the next middleware in a Buchestache block" do
      expect(Buchestache.with_instance).to receive(:log)
      middleware.call env_for('/')
    end

    it "doesn't interrupt the middleware chain" do
      expect(app).to receive(:call).and_call_original
      middleware.call env_for('/')
    end

    it "calls whatever block is given to the middleware" do
      before_block = ->(env, response) { Buchestache.with_instance.store[:before_block] = true }
      after_block = ->(env, response) { Buchestache.with_instance.store[:after_block] = true }

      middleware = Buchestache::Middleware.new(app, before_block, after_block)
      code, env = middleware.call env_for('/')
      expect(Buchestache.with_instance.store[:before_block]).to be true
      expect(Buchestache.with_instance.store[:after_block]).to be true
    end

    context 'storing data in the custom block' do
      before :each do
        block = ->(env, response) {
          request = Rack::Request.new(env)
          Buchestache.with_instance.store[:path] = request.path
        }
        @middleware = Buchestache::Middleware.new(app, block)
      end

      it "can store arbitrary data in the Buchestache store" do
        @middleware.call env_for('/')
        expect(Buchestache.with_instance.store[:path]).to eq('/')
      end

      it 'uses the stored data to build the event' do
        expect(LogStash::Event).to receive(:new).with({
          '@source' => Buchestache::STORE_NAME,
          '@fields' => { path: '/', duration: 0, status: 200, hostname: 'example.com' },
          '@tags' => []
        })
        Timecop.freeze { @middleware.call env_for('/') }
      end
    end

    context 'storing data in the rack app' do
      before :each do
        app = ->(env) do
          request = Rack::Request.new(env)
          Buchestache.with_instance.store[:scheme] = request.scheme
          [200, {}, "app"]
        end
        @middleware = Buchestache::Middleware.new(app, before_block)
      end

      it "can store arbitrary data in the Buchestache store" do
        @middleware.call env_for('/')
        expect(Buchestache.with_instance.store[:scheme]).to eq('http')
      end

      it 'uses the stored data to build the event' do
        expect(LogStash::Event).to receive(:new).with({
          '@source' => Buchestache::STORE_NAME,
          '@fields' => { scheme: 'http', duration: 0, status: 200, hostname: 'example.com' },
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
        after_block = ->(env, request) { Buchestache.with_instance.store[:foo] = @foo }
        @middleware = Buchestache::Middleware.new(app, before_block, after_block)

        expect(LogStash::Event).to receive(:new).with({
          '@source' => Buchestache::STORE_NAME,
          '@fields' => { duration: 0, status: 200, foo: 'foo', hostname: 'example.com' },
          '@tags' => [],
        })
        Timecop.freeze { @middleware.call env_for('/') }
      end
    end

    context "exception in before / after block" do
      before :each do
        before_block = ->(env, request) { 1 / 0 }
        after_block = ->(env, request) { unknown_method }
        @middleware = Buchestache::Middleware.new(app, before_block, after_block)
        STDERR.stub(:puts)
      end
      after(:each) { STDERR.unstub(:puts) }

      it "doesn't interrupt the middleware flow, logging should be transparent" do
        expect {
          @middleware.call env_for('/')
        }.to_not raise_error
      end

      it "puts the error to STDERR for easy debugging" do
        expect(STDERR).to receive(:puts).twice
        @middleware.call env_for('/')
      end
    end

    it "doesn't catch exception in the app" do
      app = ->(env) { raise }
      @middleware = Buchestache::Middleware.new(app)
      expect {
        @middleware.call env_for('/')
      }.to raise_error
    end

  end

end
