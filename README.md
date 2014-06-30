# Peastash [![build status](https://travis-ci.org/elhu/peastash.png?branch=master)](https://travis-ci.org/elhu/peastash) [![Code Climate](https://codeclimate.com/github/elhu/peastash.png)](https://codeclimate.com/github/elhu/peastash)

## Description

## Usage

### Installing

Add this line to your application's Gemfile:

```ruby
gem 'peastash'
```

### Getting started
``Peastash`` provides a simple interface to aggregate data to be sent to Logstash.
The boundaries of a log entry are defined by a the ``Peastash.with_instance.log`` block.
When the code inside the block is done running a log entry will be created and written.
The most basic usage would look like:

```ruby
Peastash.with_instance.log do
  Peastash.with_instance.store[:foo] = 'bar'
end
# This will produce a Logstash log entry looking like this:
# {"@source":"peastash","@fields":{"foo":"bar"},"@tags":[],"@timestamp":"2014-05-27T15:18:29.824Z","@version":"1"}
```

### Configuration

``Peastash`` ships with sane defaults, but can be easily configured:

```ruby
Peastash.with_instance.configure!({
  source: 'peastash', # This value will be used for the @source field of the logstash event
  # Any tag you wish to find in Logstash later (tags passed as argument to #log are added).
  tags: [], # Defaults to [].
  # Dumps to STDOUT by default. Any object answering to the dump method
  output: Peastash::Outputs::IO.new('/tmp/peastash.log'),
  store_name: 'peastash', # The key used to reference the store in the Thread.current
  dump_if_empty: true # Whether or not Peastash should produce a log entry when the store is empty
})
```

#### Outputs

Peastash ships with a single output: ``Peastash::Outputs::IO``. It can be initialized either by passing it path or an IO object.
Peastash can easily be extended to output to any target.
Simply configure Peastash's output with an object that responds to the ``#dump`` method. This method will be called at the end of the ``#log`` block, with 1 argument : a ``LogStash::Event`` object, that you will probably need to serialize to json.


### What if I want to use it in my rack app?

There's a middleware for that! Simply add the following somewhere:

```ruby
require 'peastash/middleware'
use Peastash::Middleware
```

By default, the middleware only adds the ``duration``, ``status`` and ``hostname`` (machine name) fields to the log entry.
In addition to using ``Peastash.with_instance.store`` to add information, you can pass one or two block arguments to ``use``, that will be called with the request env and the Rack response in parameter, in the context of the Middleware's instance.
The first block will be called **before** the request (with a ``response = nil``), while the second one will be called **after**, with the actual response. For example:

```ruby
require 'peastash/middleware'
before_block = ->(env, response) { Peastash.with_instance.store[:path] = Rack::Request.new(env).path }
after_block = ->(env, response) { Peastash.with_instance.store[:headers] = response[1] }
use Peastash::Middleware, before_block, after_block
# Will add 'path' and headers to the list of fields.
```

Any instance variable you set in ``before_block`` will be available in ``after_block``, but those instances variables **WILL NOT** be reset at the end of the request.

### But I want to use it in Rails!

It's easy! Simply add Peastash to your Gemfile, and add the following to the configure block of either ``config/environment.rb`` or ``config/<RAILS_ENV>.rb``:

```ruby
config.peastash.enabled = true
# You can also configure Peastash from here, for example:
config.peastash.output = Peastash::Outputs::IO.new(File.join(Rails.root, 'log', "logstash_#{Rails.env}.log"))
config.peastash.source = Rails.application.class.parent_name
```

By default, Peastash's Rails integration will log the same parameters as the Middleware version, plus the fields in the payload of the [``process_action.action_controller``](http://edgeguides.rubyonrails.org/active_support_instrumentation.html#process_action.action_controller) notification (except the params).

#### Logging request parameters

To enable parameter logging, you must add the following to your configuration:

```ruby
config.peastash.log_parameters = true
```

Be careful, as this can significantly increase the size of the log entries, as well as causing problem if other Logstash entries have the same field with a different data type.

#### Listening to ``ActiveSupport::Notifications``
Additionaly, you can use Peastash to aggregate data from any ``ActiveSupport::Notifications``:

```ruby
# In config/initializers/peastash.rb
if defined?(Peastash.with_instance.watch)
  Peastash.with_instance.watch('request.rsolr', event_group: 'solr') do |name, start, finish, id, payload, event_store|
    event_store[:queries] = event_store[:queries].to_i.succ
    event_store[:duration] = event_store[:duration].to_f + ((finish - start) * 1000)
  end
end
# This will add something like the following to the log entry fields
# {'request.rsolr': {'queries': 1, 'duration': 42}}
```

The store exposed to the blocked passed to watch is thread-safe, and reset after each request. By default, the store is only shared between occurences of the same event. You can easily share the same store between different types of notifications by assigning them to the same event group:

```ruby
Peastash.with_instance.watch('foo.notification', event_group: 'notification') do |*args, store|
  # Shared store with 'bar.notification'
end

Peastash.with_instance.watch('bar.notification', event_group: 'notification') do |*args, store|
  # Shared store with 'foo.notification'
end
```

### Playing with tags
There are three ways to tag your log entries in Peastash.with_instance.

* The first one is through configuration (see above).
* The second one is by passing tags to the ``Peastash.with_instance.log`` method.
* The last one is to call the ``Peastash.with_instance.tags`` method from within a ``Peastash.with_instance.log`` block. Tags defined with this method are not persistent and will disappear at the next call to ``Peastash.with_instance.log``

For example:

```ruby
Peastash.with_instance.configure!(tags: 'foo')
Peastash.with_instance.log(['bar']) { Peastash.with_instance.tags << 'baz' }
# Tags are ['foo', 'bar', 'baz']
Peastash.with_instance.log(['bar']) { Peastash.with_instance.tags << 'qux' }
# Tags are ['foo', 'bar', 'qux']
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

Don't forget to run the tests with `rake`.
