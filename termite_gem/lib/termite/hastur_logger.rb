module Termite
  class HasturLogger
    def initialize(socket, addr, port, labels)
      @socket, @addr, @port = socket, addr, port
      @labels = labels ? labels : {}
    end

    def to_usec(time)
      (time.to_f * 1_000_000).round
    end

    def send_message(severity, raw_message, application, time=Time.now, data={})
      severity = Logger::LOGGER_LEVEL_MAP.invert[severity].to_s
      tid = Ecology.thread_id(::Thread.current)
      hostname = Socket.gethostname
      pid = Process.pid
      application, component = application.split(":", 2)

      message = {
        :_route => :log,
        :timestamp => to_usec(time),
        :message => raw_message,
      }

      labels = {
        :severity => severity,
        :pid => pid,
        :tid => tid,
        :app => application,
        :component => component,
        :hostname => hostname
      }

      message[:labels] = labels.merge(data).merge(@labels)

      @socket.send MultiJson.encode(message), 0, @addr, @port
    end
  end
end