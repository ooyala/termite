require "rubygems"
require "termite/version"

require "ecology"
require "multi_json"

require "thread"
require "syslog"
require "logger"
require "socket"

module Termite
  class Logger
    ##
    # Maps Logger severities to syslog(3) severities.

    LOGGER_MAP = {
      :unknown => :alert,
      :fatal   => :crit,
      :error   => :err,
      :warn    => :warning,
      :info    => :info,
      :debug   => :debug,
    }

    ##
    # Maps Ruby Logger log levels to their values so we can silence.

    LOGGER_LEVEL_MAP = {}

    LOGGER_MAP.each_key do |key|
      LOGGER_LEVEL_MAP[key] = ::Logger.const_get key.to_s.upcase
    end

    ##
    # Maps Logger numerical log level values to syslog log levels.

    LEVEL_LOGGER_MAP = {}

    LOGGER_LEVEL_MAP.invert.each do |level, severity|
      LEVEL_LOGGER_MAP[level] = LOGGER_MAP[severity]
    end

    SYSLOG_SEVERITY_MAP = {}

    LOGGER_MAP.values.each do |syslog_severity|
      SYSLOG_SEVERITY_MAP[syslog_severity] = ::Syslog.const_get("LOG_" + syslog_severity.to_s.upcase)
    end

    ##
    # Builds a methods for level +meth+.

    def self.make_methods(meth)
      eval <<-EOM, nil, __FILE__, __LINE__ + 1
        def #{meth}(message = nil, data = {}, options = {}, &block)
          return true if #{LOGGER_LEVEL_MAP[meth]} < @level
          add(::Logger::#{meth.to_s.upcase}, message, data, options, &block)
        end

        def #{meth}?
          @level <= ::Logger::#{meth.to_s.upcase}
        end
      EOM
    end

    LOGGER_MAP.each_key do |level|
      make_methods level
    end

    ##
    # Log level for Logger compatibility.

    attr_accessor :level
    attr_reader :stdout_level
    attr_reader :stderr_level
    attr_reader :file_logger

    def initialize(logdev = nil, shift_age = 0, shift_size = 1048576, options = {})
      options = logdev if(logdev.is_a?(Hash))

      Ecology.read

      read_ecology_data
      @log_filename ||= logdev

      @file_logger = ::Logger.new(@log_filename, @shift_age || shift_age, @shift_size || shift_size) if @log_filename
      @extra_loggers << @file_logger if @file_logger

      # For UDP socket
      @server_addr = options[:address] || "0.0.0.0"
      @server_port = options[:port] ? options[:port].to_i : 514

      @@sockets ||= {}
      key = "#{@server_addr}:#{@server_port}"
      @@sockets[key] ||= UDPSocket.new
      @socket = @@sockets[key]
    end

    private

    def string_to_severity(str)
      orig_string = str
      str = str.strip.downcase
      return str.to_i if str =~ /\d+/
      ret = LOGGER_LEVEL_MAP[str.to_sym]
      raise "Unknown logger severity #{orig_string}" unless ret
      ret
    end

    def read_ecology_data
      @application = Ecology.application

      @extra_loggers = []

      # @console_print defaults to "yes", but can be nil if "no", "off" or "0" is specified
      @console_print = Ecology.property("logging::console_print") || "yes"
      @console_print = nil if ["no", "off", "0"].include?(@console_print)

      @log_filename = Ecology.property("logging::filename", :as => :path)
      @shift_age = Ecology.property("logging::shift_age")
      @shift_size = Ecology.property("logging::shift_size")
      @default_component = Ecology.property("logging::default_component")
      @level = Ecology.property("logging::level")
      @level = string_to_severity(@level) if @level
      @stderr_level = Ecology.property("logging::stderr_level")
      @stderr_level = string_to_severity(@stderr_level) if @stderr_level
      @stdout_level = Ecology.property("logging::stdout_level")
      @stdout_level = string_to_severity(@stdout_level) if @stdout_level

      @default_fields = Ecology.property("logging::extra_json_fields") || {}

      @level ||= ::Logger::DEBUG
      @stdout_level ||= ::Logger::INFO
      @stderr_level ||= ::Logger::ERROR
    end

    public

    def add_logger(logger)
      @extra_loggers << logger
    end

    def socket
      @socket
    end

    def raw_add(severity, message = nil, data = nil, options = {}, &block)
      # Severity is a numerical severity using Ruby Logger's scale
      severity ||= ::Logger::UNKNOWN
      return true if severity < @level

      application = options[:application] || @application

      component ||= @default_component
      component = options[:component] if options.has_key?(:component)
      if component
        application += ":" + component
      end

      data ||= {}
      if data.is_a?(Hash)
        data = @default_fields.merge(data)
        data = MultiJson.encode(data)
      elsif data.is_a?(String)
        # Can't merge a JSON string with default data
        raise "Can't merge a JSON string with extra fields!" unless @default_fields.empty?
      else
        raise "Unknown data object passed as JSON!"
      end

      tid = Ecology.thread_id(Thread.current)
      time = Time.now
      day = time.strftime("%b %d").sub(/0(\d)/, ' \\1')
      time_of_day = time.strftime("%T")
      hostname = Socket.gethostname
      tag = Syslog::LOG_LOCAL6 + SYSLOG_SEVERITY_MAP[LEVEL_LOGGER_MAP[severity]]

      syslog_string = "<#{tag}>#{day} #{time_of_day} #{hostname} #{application} [#{Process.pid}]: [#{tid}] "
      full_message = clean(message || block.call)

      # ruby_severity is the Ruby Logger severity as a symbol
      ruby_severity = LOGGER_LEVEL_MAP.invert[severity]

      full_message.split("\n").each do |line|
        message = syslog_string + "#{line} #{data}"

        begin
          @socket.send(message, 0, @server_addr, @server_port)
        rescue Exception
          # Didn't work.  Try built-in Ruby syslog
          require "syslog"
          Syslog.open(application, Syslog::LOG_PID | Syslog::LOG_CONS) do |s|
            s.error("UDP syslog failed!  Falling back to libc syslog!") rescue nil
            s.send(LEVEL_LOGGER_MAP[severity], "#{line} #{data}") rescue nil
          end
        end

        if @console_print && severity >= @stderr_level
          STDERR.puts line
        elsif @console_print && severity >= @stdout_level
          STDOUT.puts line
        end

        @extra_loggers.each do |logger|
          logger.send(ruby_severity, line) rescue nil
        end
      end

      true
    end

    def add(*args)
      begin
        raw_add(*args)
      rescue Exception => e
        STDERR.puts("Couldn't log via Termite!  Failing!  Arguments:")
        STDERR.puts(args.inspect)
        STDERR.puts("Exception: #{e.message}")
        STDERR.puts("Backtrace: #{e.backtrace.inspect}")
      end
    end

    alias :log :add

    ##
    # Allows messages of a particular log level to be ignored temporarily.
    #
    # Can you say "Broken Windows"?

    def silence(temporary_level = Logger::ERROR)
      old_logger_level = @level
      @level = temporary_level
      yield
    ensure
      @level = old_logger_level
    end

    private

    ##
    # Clean up messages so they're nice and pretty.

    def clean(message)
      message = message.to_s.dup
      message.strip!
      message.gsub!(/\e\[[^m]*m/, '') # remove useless ansi color codes
      return message
    end
  end
end
