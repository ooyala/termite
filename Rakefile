require "bundler"

require "rake/testtask"
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = Dir.glob("test/**/*test.rb")
  t.verbose = true
end

desc 'Builds the gem'
task :build do
  sh "gem build termite.gemspec"
end

desc 'Builds and installs the gem'
task :install => :build do
  sh "gem install termite-#{Termite::VERSION}"
end

desc 'Pushes the gem to gems.sv2'
task :push => :build do
  sh "gem push --host gems.sv2 termite-#{Termite::VERSION}"
end
