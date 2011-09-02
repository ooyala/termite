require File.join(File.dirname(__FILE__), "test_helper.rb")

class SubLogger < Termite::Logger
end

class TermiteSubclassTest < Scope::TestCase
  context "with subclassed termite" do
    setup do
      Ecology.reset

      ecology_text = <<ECOLOGY_TEXT
{
  "application": "foo_app"
}
ECOLOGY_TEXT

      # I'm not using the default ecology because tests have to
      # be runnable with a test runner, so $0 can be, like, anything.
      ENV['ECOLOGY_SPEC'] = "/tmp/bob.ecology"
      File.expects(:exist?).with("/tmp/bob.ecology").returns(true)
      File.expects(:read).with("/tmp/bob.ecology").returns(ecology_text)
    end

    context "and only default logging levels set" do
      setup do
        @logger = SubLogger.new
      end

      should "correctly send logs to Syslog" do
        Termite::Logger::SYSLOG.expects(:crit).with("[main]: foo! {}")
        @logger.add(Logger::FATAL, "foo!", {})
      end
    end
  end
end