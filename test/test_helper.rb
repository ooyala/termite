require "rubygems"
require "bundler"
Bundler.require(:default, :development)
require "minitest/autorun"

# For testing Termite itself, use the local version *first*.
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "termite"

class Scope::TestCase
  # Extra bits for termite testing go here
end
