require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "dotenv/load"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task :console do
  require "backblaze"
  require "irb"

  def auth!
    Backblaze::B2.login!
    Backblaze::B2.default_account
  end

  ARGV.clear
  IRB.start
end
