require 'spec_helper'
require 'peastash/middleware'
require 'pry'

describe Peastash::Middleware do
  before do
    Peastash.any_instance.stub(:enabled?) { true }
  end
  let(:app) { ->(env) { [200, {}, "app"] } }
  let(:before_block) { ->(env, response) {} }
  let(:after_block) { ->(env, response) {} }

  let(:middleware) do
    Peastash::Middleware.new(app, before_block, after_block)
  end

  describe "Rack middleware" do
    it "wraps the call to the next middleware in a Peastash block" do
      expect(Peastash.with_instance).to receive(:log)
      middleware.call env_for('/')
    end

    it "doesn't interrupt the middleware chain" do
      expect(app).to receive(:call).and_call_original
      middleware.call env_for('/')
    end

    it "calls whatever block is given to the middleware" do
      before_block = ->(env, response) { Peastash.with_instance.store[:before_block] = true }
      after_block = ->(env, response) { Peastash.with_instance.store[:after_block] = true }

      middleware = Peastash::Middleware.new(app, before_block, after_block)
      code, env = middleware.call env_for('/')
      expect(Peastash.with_instance.store[:before_block]).to be true
      expect(Peastash.with_instance.store[:after_block]).to be true
    end

    context 'storing data in the custom block' do
      before :each do
        block = ->(env, response) {
          request = Rack::Request.new(env)
          Peastash.with_instance.store[:path] = request.path
        }
        @middleware = Peastash::Middleware.new(app, block)
      end

      it "can store arbitrary data in the Peastash store" do
        @middleware.call env_for('/')
        expect(Peastash.with_instance.store[:path]).to eq('/')
      end

      it 'uses the stored data to build the event' do
        expect(LogStash::Event).to receive(:new).with({
          '@source' => Peastash::STORE_NAME,
          '@fields' => { path: '/', duration: 0, status: 200, ip: nil },
          '@tags' => []
        })
        Timecop.freeze { @middleware.call env_for('/') }
      end
    end

    context 'storing data in the rack app' do
      before :each do
        app = ->(env) do
          request = Rack::Request.new(env)
          Peastash.with_instance.store[:scheme] = request.scheme
          [200, {}, "app"]
        end
        @middleware = Peastash::Middleware.new(app, before_block)
      end

      it "can store arbitrary data in the Peastash store" do
        @middleware.call env_for('/')
        expect(Peastash.with_instance.store[:scheme]).to eq('http')
      end

      it 'uses the stored data to build the event' do
        expect(LogStash::Event).to receive(:new).with({
          '@source' => Peastash::STORE_NAME,
          '@fields' => { scheme: 'http', duration: 0, status: 200, ip: nil },
          '@tags' => []
        })
        Timecop.freeze { @middleware.call env_for('/') }
      end
    end

    context 'without a custom block' do
      it "doesn't try to call the block" do
        @middleware = Peastash::Middleware.new(app)
        expect {
          @middleware.call env_for('/')
        }.to_not raise_error
      end
    end

    context 'persistence between before/after block' do
      it "saves instance variables between before/after block" do
        before_block = ->(env, request) { @foo = 'foo' }
        after_block = ->(env, request) { Peastash.with_instance.store[:foo] = @foo }
        @middleware = Peastash::Middleware.new(app, before_block, after_block)

        expect(LogStash::Event).to receive(:new).with({
          '@source' => Peastash::STORE_NAME,
          '@fields' => { duration: 0, status: 200, foo: 'foo', ip: nil },
          '@tags' => [],
        })
        Timecop.freeze { @middleware.call env_for('/') }
      end
    end

    context "exception in before / after block" do
      before :each do
        Peastash.safe!
        before_block = ->(env, request) { 1 / 0 }
        after_block = ->(env, request) { unknown_method }
        @middleware = Peastash::Middleware.new(app, before_block, after_block)
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
      Peastash.safe!
      app = ->(env) { raise }
      @middleware = Peastash::Middleware.new(app)
      expect {
        @middleware.call env_for('/')
      }.to raise_error
    end

  end

end
