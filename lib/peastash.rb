require 'logstash/event'
require 'thread_safe'
require 'peastash/outputs/io'
require 'peastash/rails_ext' if defined?(Rails)

class Peastash

  STORE_NAME = 'peastash'

  class << self

    def configure!(conf = {})
      with_instance.configure!(conf)
    end

    def with_instance(instance_name = :global)
      @@instance_cache[instance_name] ||= Peastash.new(instance_name)
    end

    def safely
      yield
    rescue StandardError => e
      STDERR.puts e.inspect
      STDERR.puts e.backtrace
      raise e unless safe?
    end

    def safe?
      !@unsafe
    end

    def safe!
      @unsafe = false
    end

    def unsafe!
      @unsafe = true
    end

  end

  attr_reader :instance_name
  attr_accessor :configuration

  @@instance_cache = ThreadSafe::Cache.new

  def initialize(instance_name)
    @instance_name = instance_name

    @configuration = {
      :source => STORE_NAME,
      :tags => [],
      :output => Outputs::IO.new(Outputs::IO::default_io),
      :store_name => STORE_NAME,
      :dump_if_empty => true
    }

    configure!(@@instance_cache[:global].configuration || {}) if @@instance_cache[:global]
  end

  def store
    Thread.current[instance_name] ||= Hash.new
    Thread.current[instance_name][@store_name] ||= Hash.new { |hash, key| hash[key] = {} }
  end

  def configure!(conf = {})
    self.configuration.merge!(conf)
    @source = configuration[:source]
    @base_tags = configuration[:tags].flatten
    @output = configuration[:output]
    @store_name = configuration[:store_name]
    @dump_if_empty = configuration[:dump_if_empty]
    @configured = true
  end

  def log(additional_tags = [])
    Peastash.safely do
      configure! unless configured?
      tags.replace(additional_tags)
      store.clear
    end

    yield(instance)

    Peastash.safely do
      if enabled? && (!store.empty? || dump_if_empty?)
        event = build_event(@source, tags)
        @output.dump(event)
      end
      tags.clear
    end
  end

  def tags
    Peastash.safely do
      configure! unless configured?
      Thread.current[instance_name] ||= Hash.new
      Thread.current[instance_name][@store_name + ":tags"] ||= []
    end
  end

  def enabled?
    !!configuration[:enabled]
  end

  def instance
    @@instance_cache[instance_name]
  end

  private

  def configured?
    @configured
  end

  def dump_if_empty?
    @dump_if_empty
  end

  def build_event(source, tags)
    LogStash::Event.new({
      '@source' => source,
      '@fields' => store,
      '@tags' => @base_tags + tags,
      '@pid' => Process.pid
    })
  end
end
