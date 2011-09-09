require "rubygems"
require "bundler"
Bundler.require(:default, :development)
require "minitest/autorun"

# For testing Termite itself, use the local version *first*.
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "termite"

class Scope::TestCase
  def set_up_ecology(file_contents, filename = "some.ecology")
    ENV["ECOLOGY_SPEC"] = filename
    File.expects(:exist?).with(filename).returns(true)
    File.expects(:read).with(filename).returns(file_contents)
  end

  # Extra bits for termite testing go here
  def expect_add(socket, severity_num, message, options = {})
    unless @initialized_expect_add
      Time.stubs(:now).returns(Time.at(1315433360))
      Socket.stubs(:gethostname).returns("samplehost")
      Process.stubs(:pid).returns("1234")
      Ecology.stubs(:thread_id).returns("main")

      @initialized_expect_add = true
    end

    app = options[:application] || "foo_app"
    string = "<#{Syslog::LOG_LOCAL6 + severity_num}>Sep  7 15:09:20 samplehost #{app} [1234]: [main] #{message}"
    socket.expects(:send).with(string, 0, "0.0.0.0", 514)
  end
end
