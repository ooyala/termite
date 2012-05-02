require "rubygems"
require "bundler"
Bundler.require(:default, :development)
require "minitest/autorun"

# For testing Termite itself, use the local version *first*.
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "termite"
require "ecology/test_methods"

class Scope::TestCase
  include Ecology::Test

  def initialize_environment
    unless @initialized_test_env
      Time.stubs(:now).returns(Time.at(1315433360))
      Socket.stubs(:gethostname).returns("samplehost")
      Process.stubs(:pid).returns("1234")
      Ecology.stubs(:thread_id).returns("main")
      ENV.delete "TERMITE_DEBUG"

      @initialized_test_env = true
    end
  end

  # This adds the Mocha expectation for this call.  Technically it also
  # returns the expectation, so you could modify it later if you wanted.
  def expect_add(severity_num, message, options = {})
    initialize_environment

    app = options[:application] || "foo_app:whatcomponent"
    syslog_mock = mock("Syslog connection")
    Syslog.expects(:open).with(app, Syslog::LOG_PID | Syslog::LOG_CONS).yields(syslog_mock)

    syslog_mock.expects(Termite::Logger::SYSLOG_SEVERITY_MAP.invert[severity_num]).with(message)
  end

  def expect_udp(socket, severity_num, message, options = {})
    initialize_environment
    app = options[:application] || "foo_app:whatcomponent"
    string = "<#{Syslog::LOG_LOCAL6 + severity_num}>Sep  7 15:09:20 samplehost #{app} [1234]: [main] #{message}"
    options[:method] ||= :send
    options[:extra_args] ||= [0, "0.0.0.0", 514]
    socket.expects(options[:method]).with(string, *options[:extra_args])
  end

  def expect_console_add(socket, severity_num, message, options = {})
    initialize_environment

    app = options[:application] || "foo_app"

    options[:method] ||= :send
    options[:extra_args] ||= [0, "0.0.0.0", 514]
    socket.expects(:<<).with(message + "\n", *options[:extra_args])
  end
end
