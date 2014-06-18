require 'logstash/event'
require 'thread_safe'
require 'buchestache/outputs/io'
require 'buchestache/rails_ext' if defined?(Rails)

class Buchestache
  STORE_NAME = 'buchestache'
  @@instance_cache = ThreadSafe::Cache.new

  attr_accessor :configuration
  attr_reader :instance_name

  def initialize(instance_name)
    @instance_name = instance_name
  end

  def store
    Thread.current[instance_name] ||= Hash.new
    Thread.current[instance_name][@store_name] ||= Hash.new { |hash, key| hash[key] = {} }
  end

  def configure!(conf = {})
    self.configuration = conf
    @source = conf[:source] || STORE_NAME
    @base_tags = [conf[:tags] || []].flatten
    @output = conf[:output] || Outputs::IO.new(Outputs::IO::default_io)
    @store_name = conf[:store_name] || STORE_NAME
    @dump_if_empty = conf.has_key?(:dump_if_empty) ? conf[:dump_if_empty] : true
    @configured = true
  end

  def log(additional_tags = [])
    configure! unless configured?
    tags.replace(additional_tags)
    store.clear
    yield
    if !store.empty? || dump_if_empty?
      event = build_event(@source, tags)
      @output.dump(event)
    end
  end

  def tags
    Thread.current[@store_name + ":tags"] ||= []
  end

  def self.instance(instance_name = :global)
    @@instance_cache[instance_name] ||= Buchestache.new(instance_name)
  end

  private
  def configured?
    @configured
  end

  def dump_if_empty?
    @dump_if_empty
  end

  def build_event(source, tags)
    LogStash::Event.new('@source' => source, '@fields' => store, '@tags' => @base_tags + tags)
  end
end
