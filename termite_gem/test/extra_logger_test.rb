require File.join(File.dirname(__FILE__), "test_helper.rb")

class TermiteExtraLoggerTest < Scope::TestCase
  context "with termite" do
    setup do
      $0 = "MyApp"
      Ecology.reset
    end

    context "and two extra loggers added" do
      setup do
        @logger = Termite::Logger.new("/tmp/test_log_output.txt")  # Test with output file
        @logger.level = Logger::DEBUG
        @logger.socket.expects(:send)
        @mock_logger_1 = mock()
        @mock_logger_2 = mock()
        @logger.add_logger(@mock_logger_1)
        @logger.add_logger(@mock_logger_2)
      end

      should "correctly send logs to additional loggers" do
        @mock_logger_1.expects(:<<).with("foo!")
        @mock_logger_2.expects(:<<).with("foo!")
        @logger.add(Logger::FATAL, "foo!", {})
      end
    end
  end
end
