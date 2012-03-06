module Termite
  class SyslogLogger
    def initialize(socket, server_addr, server_port)
      @socket, @server_addr, @server_port = socket, server_addr, server_port
    end

    def send_message(severity, full_message, application, time=Time.now, data={})
      tid = Ecology.thread_id(::Thread.current)
      day = time.strftime("%b %d").sub(/0(\d)/, ' \\1')
      time_of_day = time.strftime("%T")
      hostname = Socket.gethostname

      # Convert Ruby log level to syslog severity
      tag = Syslog::LOG_LOCAL6 + Logger::SYSLOG_SEVERITY_MAP[Logger::LEVEL_SYSLOG_MAP[severity]]
      syslog_string = "<#{tag}>#{day} #{time_of_day} #{hostname} #{application} [#{Process.pid}]: [#{tid}] "

      # ruby_severity is the Ruby Logger severity as a symbol
      ruby_severity = Logger::LOGGER_LEVEL_MAP.invert[severity]

      full_message.split("\n").each do |line|
        syslog_message = syslog_string + "#{line} #{data}"

        begin
          @socket.send(syslog_message, 0, @server_addr, @server_port)
        rescue Exception
          # Didn't work.  Try built-in Ruby syslog
          require "syslog"
          Syslog.open(application, Syslog::LOG_PID | Syslog::LOG_CONS) do |s|
            s.error("Socket syslog failed!  Falling back to libc syslog!") rescue nil
            s.send(Logger::LEVEL_SYSLOG_MAP[severity], "#{line} #{data}") rescue nil
          end
        end
      end
    end

  end
end