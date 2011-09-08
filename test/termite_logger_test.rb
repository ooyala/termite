require File.join(File.dirname(__FILE__), "test_helper.rb")
require "syslog"

class TermiteLoggerTest < Scope::TestCase
  def expect_add(socket, severity_num, message, options = {})
    app = options[:application] || "foo_app"
    string = "<#{Syslog::LOG_LOCAL6 + severity_num}>Sep  7 15:09:20 samplehost #{app} [1234]: [main] #{message}"
    socket.expects(:send).with(string, 0, "0.0.0.0", 514)
  end

  context "with termite ecology" do
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

      Time.stubs(:now).returns(Time.at(1315433360))
      Socket.stubs(:gethostname).returns("samplehost")
      Process.stubs(:pid).returns("1234")
      Ecology.stubs(:thread_id).returns("main")
    end

    context "and fully permissive logging levels set" do
      setup do
        @socket = mock("UDP socket")
        UDPSocket.stubs(:new).returns(@socket)

        @logger = Termite::Logger.new("/tmp/test_log_output.txt")  # Test with output file
        @logger.level = Logger::DEBUG
      end

      should "correctly send logs to Syslog" do
        expect_add(@socket, 2, "foo! {}")
        @logger.add(Logger::FATAL, "foo!", {})
      end

      should "correctly send an alert to Syslog" do
        expect_add(@socket, 1, "foo! {}")
        @logger.add(Logger::UNKNOWN, "foo!", {})
      end

      should "correctly send a critical event to Syslog" do
        expect_add(@socket, 2, "foo! {}")
        @logger.fatal("foo!")
      end

      should "correctly send an error event to Syslog" do
        expect_add(@socket, 3, "foo! {}")
        @logger.error("foo!")
      end

      should "correctly send a warning event to Syslog" do
        expect_add(@socket, 4, "foo! {}")
        @logger.warn("foo!")
      end

      should "correctly send an info event to Syslog" do
        expect_add(@socket, 6, "foo! {}")
        @logger.info("foo!")
      end

      should "correctly send a debug event to Syslog" do
        expect_add(@socket, 7, "foo! {}")
        @logger.debug("foo!")
      end
    end

    context "and default setup for components" do
      setup do
        @socket = mock("UDP socket")
        UDPSocket.stubs(:new).returns(@socket)
        @logger = Termite::Logger.new("/tmp/test_log_output.txt")  # Test with output file
      end

      should "allow overriding application name" do
        expect_add(@socket, 2, "foo! {}", :application => "bar_app")
        @logger.fatal("foo!", {}, :application => "bar_app")
      end

      should "allow setting a component" do
        expect_add(@socket, 2, "foo! {}", :application => "foo_app:whatcomponent")
        @logger.fatal("foo!", {}, :component => "whatcomponent")
      end
    end

  end
end
