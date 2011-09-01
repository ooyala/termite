require File.join(File.dirname(__FILE__), "test_helper.rb")

class TermiteLoggerTest < Scope::TestCase
  context "with termite manifest" do
    setup do
      Termite.reset

      manifest_text = <<MANIFEST_TEXT
{
  "application": "foo_app"
}
MANIFEST_TEXT

      # I'm not using the default manifest because tests have to
      # be runnable with a test runner, so $0 can be, like, anything.
      ENV['TERMITE_MANIFEST'] = "/tmp/bob.txt"
      File.expects(:read).with("/tmp/bob.txt").returns(manifest_text)
    end

    context "and only default logging levels set" do
      setup do
        @logger = Termite::Logger.new
      end

      should "correctly send logs to Syslog" do
        SyslogLogger::SYSLOG.expects(:err).with("[main]: foo! {}")
        @logger.add(Logger::FATAL, "foo!", {})
      end
    end
  end
end
