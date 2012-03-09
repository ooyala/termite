require File.join(File.dirname(__FILE__), "test_helper.rb")

class HasturLoggerTest < Scope::TestCase

  def expect_send(raw_message, data)
    message = {
      :_route => :log,
      :timestamp => @time_usec,
      :message => raw_message
    }

    labels = {
      :severity => "warn",
      :pid => @pid,
      :tid => @tid,
      :app => @app_data[:app],
      :component => @app_data[:component],
      :hostname => @host
    }

    message[:labels] = labels.merge(MultiJson.decode(data)).merge(@labels)
    json_message = MultiJson.encode(message)

    @socket.expects(:send).with(json_message, 0, @addr, @port)
  end

  context "with a hastur logger" do
    setup do
      @socket = mock("UDP Socket")
      @labels = {"hi" => "lo", "fast" => "slo"}
      @addr = "127.0.0.1"
      @port = 8125
      @logger = Termite::HasturLogger.new(@socket, @addr, @port, @labels)
    end

    context "will send a message" do
      setup do
        @severity = 2
        @raw_message = "message"
        @app_data = {:combined => "app:comp", :app => "app", :component => "comp"}
        @pid = 123
        @tid = "main"
        @time = 345
        @time_usec = 345_000_000
        @host = "host"
        Ecology.stubs(:thread_id).returns(@tid)
        Process.stubs(:pid).returns(@pid)
        Time.stubs(:now).returns(@time)
        Socket.stubs(:gethostname).returns(@host)
      end

      should "send back extra JSON data and labels when specified" do
        expect_send("oh no!", '{"app_group":"SuperSpiffyGroup","precedence":7}')
        @logger.send_message(@severity, "oh no!", @app_data, Time.now, '{"app_group":"SuperSpiffyGroup","precedence":7}')
      end
    end
  end
end