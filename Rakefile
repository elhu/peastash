$:.unshift File.expand_path('../lib', __FILE__)

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new

task :default => :spec
task :test => :spec

task :console do
  require 'irb'
  require 'irb/completion'
  require 'buchestache'
  ARGV.clear
  IRB.start
end
