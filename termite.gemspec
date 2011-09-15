# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

require "termite/version"

Gem::Specification.new do |s|
  s.name        = "termite"
  s.version     = Termite::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Noah Gibbs"]
  s.email       = ["noah@ooyala.com"]
  s.homepage    = "http://www.ooyala.com"
  s.summary     = %q{Ruby logging based on Syslog}
  s.description = <<EOS
Termite wraps syslog with a format for extra data, and for
what you wish it would send automatically.
EOS

  s.rubyforge_project = "termite"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "multi_json"
  s.add_dependency "ecology", "~>0.0.3"

  s.add_development_dependency "bundler", "~> 1.0.10"
  s.add_development_dependency "scope", "~> 0.2.1"
  s.add_development_dependency "mocha"
  s.add_development_dependency "rake"
end
