require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "standard/rake"
require "dotenv/tasks"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

task console: :dotenv do
  require "backblaze"
  require "irb"

  def auth!
    Backblaze::B2.login!
    Backblaze::B2.default_account
  end

  ARGV.clear
  IRB.start
end
