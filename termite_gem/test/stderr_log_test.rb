require File.join(File.dirname(__FILE__), "test_helper.rb")

class StderrLogTest < Scope::TestCase
  context "with a custom ecology" do
    setup do
      Ecology.reset

      set_up_ecology <<ECOLOGY_CONTENTS
{
  "application": "MyApp",
  "logging": {
    "stdout_level": "warn",
    "stderr_level": "fatal",
    "stdout_color": "green"
  }
}
ECOLOGY_CONTENTS
    end

    context "with a default termite logger" do
      setup do
        @stdout_logger = mock("STDOUT logger")
        ::Logger.expects(:new).with(STDOUT).returns(@stdout_logger)
        @stderr_logger = mock("STDERR logger")
        ::Logger.expects(:new).with(STDERR).returns(@stderr_logger)
        @logger = Termite::Logger.new
      end

      should "log fatal errors to STDERR with default color" do
        @stderr_logger.expects(:<<).with("oh no!".color(:red))
        STDOUT.expects(:puts).never
        @logger.fatal("oh no!")
      end

      should "log warnings to STDOUT with overridden color" do
        @stdout_logger.expects(:<<).with("oh no!".color(:green))
        STDERR.expects(:puts).never
        @logger.warn("oh no!")
      end

    end
  end
end
