require File.join(File.dirname(__FILE__), "test_helper.rb")
require "syslog"

class TermiteLoggerTest < Scope::TestCase
  context "with termite ecology" do
    setup do
      Ecology.reset

      set_up_ecology <<ECOLOGY_TEXT
{
  "application": "foo_app",
  "logging":
    {
      "default_component": "whatcomponent"
    }
}
ECOLOGY_TEXT
    end

    context "and fully permissive logging levels set" do
      setup do
        @logger = Termite::Logger.new("/tmp/test_log_output.txt")  # Test with output file
        @logger.level = Logger::DEBUG
      end

      should "correctly send logs to Syslog" do
        expect_add(2, "foo! {}")
        @logger.add(Logger::FATAL, "foo!", {})
      end

      should "correctly alias log to add" do
        expect_add(2, "foo! {}")
        @logger.log(Logger::FATAL, "foo!", {})
      end

      should "treat << as add-with-info" do
        expect_add(6, "foo! {}")
        @logger << "foo!"
      end

      should "correctly send an alert to Syslog" do
        expect_add(1, "foo! {}")
        @logger.add(Logger::UNKNOWN, "foo!", {})
      end

      should "correctly send a critical event to Syslog" do
        expect_add(2, "foo! {}")
        @logger.fatal("foo!")
      end

      should "correctly send an error event to Syslog" do
        expect_add(3, "foo! {}")
        @logger.error("foo!")
      end

      should "correctly send a warning event to Syslog" do
        expect_add(4, "foo! {}")
        @logger.warn("foo!")
      end

      should "correctly send an info event to Syslog" do
        expect_add(6, "foo! {}")
        @logger.info("foo!")
      end

      should "correctly send a debug event to Syslog" do
        expect_add(7, "foo! {}")
        @logger.debug("foo!")
      end
    end

    context "and default setup for components" do
      setup do
        @logger = Termite::Logger.new("/tmp/test_log_output.txt")  # Test with output file
      end

      should "override application name from ecology" do
        expect_add(2, "foo! {}", :application => "bar_app:whatcomponent")
        @logger.fatal("foo!", {}, :application => "bar_app")
      end

      should "override component from ecology" do
        expect_add(2, "foo! {}", :application => "foo_app:thatcomponent")
        @logger.fatal("foo!", {}, :component => "thatcomponent")
      end

      should "override application and component from ecology" do
        expect_add(2, "foo! {}", :application => "bar_app:thatcomponent")
        @logger.fatal("foo!", {}, :application => "bar_app", :component => "thatcomponent")
      end
    end

  end
end
