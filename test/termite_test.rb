require File.join(File.dirname(__FILE__), "test_helper.rb")
require "thread"

class TermiteTest < Scope::TestCase
  context "with termite manifest" do
    should "correctly determine default manifest names" do
      assert_equal "/path/to/bob.txt.fj", Termite.default_manifest_name("/path/to/bob.txt.rb")
      assert_equal "relative/path/to/app.fj", Termite.default_manifest_name("relative/path/to/app.rb")
      assert_equal "/path/to/bob.fj", Termite.default_manifest_name("/path/to/bob.sh")
      assert_equal "\\path\\to\\bob.fj", Termite.default_manifest_name("\\path\\to\\bob.EXE")
    end

    should "respect the TERMITE_MANIFEST environment variable" do
      Termite.reset
      ENV['TERMITE_MANIFEST'] = '/tmp/bobo.txt'
      File.expects(:read).with('/tmp/bobo.txt').returns('{ "application": "foo_app" }')
      Termite.read_manifest

      assert_equal "foo_app", Termite.application      
    end

    should "Recognize that this is the main thread" do
      assert_equal "main", Termite.thread_id(Thread.current)
    end

  end
end
