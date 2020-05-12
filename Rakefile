require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "dotenv/load"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task :console do
  require "backblaze"
  require "irb"

  ARGV.clear
  IRB.start
end
