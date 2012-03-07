require "syslog"

module Termite
  class SyslogLogger
    def initialize(socket, server_addr, server_port, transport)
      @socket, @server_addr, @server_port, @transport = socket, server_addr, server_port, transport
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
        syslog_message = "#{line} #{data}"
        case @transport
        when "UDP"
          send_udp(severity, syslog_string, syslog_message, application)
        when "syscall", "libc"
          send_libc(severity, syslog_message, application) rescue nil
        else
          send_libc(severity, syslog_message, application) rescue
            send_udp(severity, syslog_string, syslog_message, application)
        end
      end
    end

    def send_udp(severity, syslog_string, syslog_message, application)
        @socket.send(syslog_string + syslog_message, 0, @server_addr, @server_port) rescue nil
    end

    def send_libc(severity, syslog_message, application)
      Syslog.open(application, Syslog::LOG_PID | Syslog::LOG_CONS) do |s|
        s.send(Logger::LEVEL_SYSLOG_MAP[severity], syslog_message)
      end
    end
  end
end