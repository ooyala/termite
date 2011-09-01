require File.join(File.dirname(__FILE__), "test_helper.rb")
require "thread"

class TermiteTest < Scope::TestCase
  context "with termite personifest" do
    should "correctly determine default personifest names" do
      assert_equal "/path/to/bob.txt.fj", Termite.default_personifest_name("/path/to/bob.txt.rb")
      assert_equal "relative/path/to/app.fj", Termite.default_personifest_name("relative/path/to/app.rb")
      assert_equal "/path/to/bob.fj", Termite.default_personifest_name("/path/to/bob.sh")
      assert_equal "\\path\\to\\bob.fj", Termite.default_personifest_name("\\path\\to\\bob.EXE")
    end

    should "respect the TERMITE_PERSONIFEST environment variable" do
      Termite.reset
      ENV['TERMITE_PERSONIFEST'] = '/tmp/bobo.txt'
      File.expects(:read).with('/tmp/bobo.txt').returns('{ "application": "foo_app" }')
      Termite.read_personifest

      assert_equal "foo_app", Termite.application      
    end

    should "Recognize that this is the main thread" do
      assert_equal "main", Termite.thread_id(Thread.current)
    end

  end
end
