# Buchestache [![build status](https://travis-ci.org/elhu/buchestache.png?branch=master)](https://travis-ci.org/elhu/buchestache) [![Code Climate](https://codeclimate.com/github/elhu/buchestache.png)](https://codeclimate.com/github/elhu/buchestache)

## Description

## Usage

### Installing

Add this line to your application's Gemfile:

```ruby
gem 'buchestache'
```

### Getting started
``Buchestache`` provides a simple interface to aggregate data to be sent to Logstash.
The boundaries of a log entry are defined by a the ``Buchestache.log`` block.
When the code inside the block is done running a log entry will be created and written.
The most basic usage would look like:

```ruby
Buchestache.log do
  Buchestache.store[:foo] = 'bar'
end
# This will produce a Logstash log entry looking like this:
# {"@source":"buchestache","@fields":{"foo":"bar"},"@tags":[],"@timestamp":"2014-05-27T15:18:29.824Z","@version":"1"}
```

### Configuration

``Buchestache`` ships with sane defaults, but can be easily configured:

```ruby
Buchestache.configure!({
  source: 'buchestache', # This value will be used for the @source field of the logstash event
  tags: [], # Defaults to [].
  Any tag you wish to find in Logstash later (tags passed as argument to #log are added).
  # Dumps to STDOUT by default. Any object answering to the dump method
  output: Buchestache::Outputs::IO.new('/tmp/buchestache.log'),
  store_name: 'buchestache', # The key used to reference the store in the Thread.current
  dump_if_empty: true # Whether or not Buchestache should produce a log entry when the store is empty
})
```

#### Outputs

Buchestache ships with a single output: ``Buchestache::Outputs.IO``. It can be initialized either by passing it path or an IO object.
Buchestache can easily be extended to output to any target.
Simply configure Buchestache's output with an object that responds to the ``#dump`` method. This method will be called at the end of the ``#log`` block, with 1 argument : a ``LogStash::Event`` object, that you will probably need to serialize to json.


### What if I want to use it in my rack app?

There's a middleware for that! Simply add the following somewhere:

```ruby
require 'buchestache/middleware'
use Buchestache::Middleware
```

By default, the middleware only adds the ``duration`` and ``status`` fields to the log entry. To add more information, you can:

* Put anything in the store by calling ``Buchestache.store``
* Give a block argument to ``use``, that will be called with the request env and the Rack response in parameter. For example:

```ruby
require 'buchestache/middleware'
block = ->(env, response) { Buchestache.store[:path] = Rack::Request.new(env).path }
use Buchestache::Middleware, &block
# Will add 'path' to the list of fields.
```

### But I want to use it in Rails!

Simmer down, it's coming! For now, you can use it in Rails like you would use it in any other Rack app.
Soon, you'll be able to just include it in your Gemfile, and start logging to Logstash right after!

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

Don't forget to run the tests with `rake`.
