require File.join(File.dirname(__FILE__), "test_helper.rb")
require "syslog"

class RescueTest < Scope::TestCase
  context "with termite" do
    setup do
      Ecology.reset
      @logger = Termite::Logger.new("/tmp/termite_test.log")
    end

    should "continue even if all loggers raise errors" do
      # First, UDP will raise an error
      @logger.socket.expects(:send).raises(StandardError, "You suck!")

      # Termite should fall back to trying Ruby Syslog...
      syslog_mock = mock("Syslog connection")
      Syslog.expects(:open).yields(syslog_mock)
      syslog_mock.expects(:error).with("UDP syslog failed!  Falling back to libc syslog!")
      syslog_mock.expects(:crit).raises(StandardError, "You suck even more than that!")

      # And it should still try to write to a file logger - this is now just an extra logger
      # @logger.file_logger.expects(:fatal).raises(StandardError, "You suck lots!")

      extra_logger = mock("Additional logger")
      @logger.add_logger(extra_logger)
      # And it should try to write to any extra loggers
      extra_logger.expects(:<<).raises(StandardError, "You suck constantly!")

      # And yet, nothing should be raised to the outside world
      begin
        @logger.fatal("Woe is me!")
        assert true, "Nothing was raised!  Yay!"
      rescue Exception
        flunk "Logging an event raised an assertion outside the logger!"
      end
    end

    should "continue even if internal logic gives an error" do
      Ecology.expects(:thread_id).raises(Exception.new "Ecology thread_id dies!")
      begin
        @logger.fatal("Woe is me!")
        assert true, "Nothing was raised!  Yay!"
      rescue Exception
        flunk "Logging an event raised an assertion outside the logger!"
      end
    end
  end
end
