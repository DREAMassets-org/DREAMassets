# Rake tasks for ruby

require "bundler/inline"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.test_files = FileList['test/ruby/**/test_*.rb']
end
desc "Run Ruby Tests"

task default: :test
