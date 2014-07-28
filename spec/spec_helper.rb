$:.unshift File.expand_path('../lib', __FILE__)

# ENV['RACK_ENV'] = 'test'
# ENV['RAILS_ENV'] = 'test'

require 'timecop'
require 'simplecov'
require 'rack/test'

require 'peastash'

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.before(:all) do
    # Muting the output from the logger
    Peastash::Outputs::IO.class_variable_set(:@@default_io, File.open(File::NULL, File::WRONLY))
  end
end

def unconfigure_foostash!
  Peastash.class_variable_set(:@@instance_cache, ThreadSafe::Cache.new)
end

def env_for(url, opts={})
  Rack::MockRequest.env_for(url, opts)
end
