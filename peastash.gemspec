lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'peastash/version'

Gem::Specification.new do |gem|
  gem.name          = "peastash"
  gem.version       = Peastash::VERSION
  gem.authors       = ["Vincent Boisard"]
  gem.email         = ["boisard.v@gmail.com"]
  gem.description   = %q{Peastash allows you to instrument your code with the ELK stack easily.}
  gem.summary       = %q{Peastash allows you to instrument your code with the ELK stack easily.}
  gem.homepage      = "http://github.com/elhu/peastash"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency "logstash-event"
  gem.add_runtime_dependency "thread_safe"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec", '~> 2.14'
  gem.add_development_dependency "rspec-rails"
  gem.add_development_dependency "rack-test"
  gem.add_development_dependency "simplecov", '~> 0.7.1'
  gem.add_development_dependency "timecop"
  gem.add_development_dependency "pry"
  gem.add_development_dependency "rails"
end
