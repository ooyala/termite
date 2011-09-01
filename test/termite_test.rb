require File.join(File.dirname(__FILE__), "test_helper.rb")
require "thread"

class TermiteTest < Scope::TestCase
  context "with ecology" do
    should "correctly determine default ecology names" do
      assert_equal "/path/to/bob.txt.ecology", Ecology.default_ecology_name("/path/to/bob.txt.rb")
      assert_equal "relative/path/to/app.ecology", Ecology.default_ecology_name("relative/path/to/app.rb")
      assert_equal "/path/to/bob.ecology", Ecology.default_ecology_name("/path/to/bob.sh")
      assert_equal "\\path\\to\\bob.ecology", Ecology.default_ecology_name("\\path\\to\\bob.EXE")
    end

    should "respect the TERMITE_ECOLOGY environment variable" do
      Ecology.reset
      ENV['TERMITE_ECOLOGY'] = '/tmp/bobo.txt'
      File.expects(:read).with('/tmp/bobo.txt').returns('{ "application": "foo_app" }')
      Ecology.read

      assert_equal "foo_app", Ecology.application
    end

    should "Recognize that this is the main thread" do
      assert_equal "main", Ecology.thread_id(Thread.current)
    end

  end
end
