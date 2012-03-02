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

    # Get Ruby Logger labels for Logger-compatible output
    RUBY_LOGGER_SEV_LABELS = ::Logger::SEV_LABEL

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

    def initialize(logdev = nil, shift_age = nil, shift_size = nil, options = {})
      if logdev.is_a?(Hash)
        options = logdev
        logdev = nil
      end

      Ecology.read

      @extra_loggers ||= []
      @log_filename ||= logdev
      @shift_age ||= shift_age
      @shift_size ||= shift_size

      read_ecology_data(options)

      setup_file_logger if @log_filename

      setup_syslog_vars(options)
    end

    private

    def read_ecology_data(options = {})
      @application = Ecology.application
      @default_component = options[:default_component] || options[:component] ||
        Ecology.property("logging::default_component")

      # @console_print defaults to "yes", but can be nil if "no", "off" or "0" is specified
      @console_print = options[:console_print] || Ecology.property("logging::console_print") || "yes"
      @console_print = nil if ["no", "off", "0"].include?(@console_print)

      Ecology.property("logging::sinks") ? read_sinked_ecology(options) : read_unsinked_ecology(options)

      @default_fields = Ecology.property("logging::extra_json_fields") || {}

      @level ||= ::Logger::DEBUG
      @stdout_level ||= ::Logger::INFO
      @stderr_level ||= ::Logger::ERROR
    end

    def read_sinked_ecology(options)

    end

    # This is the codepath for ecology files that do not have a 'sinks' section defined
    def read_unsinked_ecology(options)
      @log_filename = options[:logging_filename] || Ecology.property("logging::filename", :as => :path)
      @shift_age = options[:shift_age] || Ecology.property("logging::shift_age")
      @shift_size = options[:shift_size] || Ecology.property("logging::shift_size")
      @level = options[:level] || Ecology.property("logging::level")
      @level = string_to_severity(@level) if @level
      @stderr_level = options[:stderr_level] || Ecology.property("logging::stderr_level")
      @stderr_level = string_to_severity(@stderr_level) if @stderr_level
      @stdout_level = options[:stdout_level] || Ecology.property("logging::stdout_level")
      @stdout_level = string_to_severity(@stdout_level) if @stdout_level
      @stderr_logger_prefix = options[:stderr_logger_prefix] ||
        Ecology.property("logging::stderr_logger_prefix")
      @stdout_logger_prefix = options[:stdout_logger_prefix] ||
        Ecology.property("logging::stdout_logger_prefix")
      @file_logger_prefix = options[:use_logger_prefix] ||
        Ecology.property("logging::use_logger_prefix")

    end

    def string_to_severity(str)
      orig_string = str
      str = str.strip.downcase
      return str.to_i if str =~ /\d+/
      ret = LOGGER_LEVEL_MAP[str.to_sym]
      raise "Unknown logger severity #{orig_string}" unless ret
      ret
    end

    def setup_file_logger
      @file_logger = ::Logger.new(@log_filename, @shift_age || 0, @shift_size || 1048576)
      @extra_loggers << @file_logger
    end

    def setup_syslog_vars(options)
      # For UDP socket
      @server_addr = options[:address] || "0.0.0.0"
      @server_port = options[:port] ? options[:port].to_i : 514
      @socket = find_or_create_socket
    end

    def find_or_create_socket
      @@sockets ||= {}
      key = "#{@server_addr}:#{@server_port}"
      @@sockets[key] ||= UDPSocket.new
    end

    public

    def add_logger(logger)
      @extra_loggers << logger
    end

    def socket
      @socket
    end

    def raw_add(severity, message = nil, data = nil, options = {}, &block)
      raw_message = message
      # Severity is a numerical severity using Ruby Logger's scale
      severity ||= ::Logger::UNKNOWN
      return true if severity < @level

      application = options[:application] || @application
      component = @default_component
      component = options[:component] if options.has_key?(:component)

      application += ":" + component if component

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

      tid = Ecology.thread_id(::Thread.current)
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
      end

      # Lifted from Logger::Formatter
      ruby_logger_severity = RUBY_LOGGER_SEV_LABELS[severity]
      ruby_logger_message = "%s, [%s#%d] %5s -- %s: %s" % [ruby_logger_severity[0..0],
          (time.strftime("%Y-%m-%dT%H:%M:%S.") << "%06d " % time.usec),
          $$, ruby_logger_severity, "", raw_message]

      # Ruby puts does two writes: one of the string passed in and one of a newline.  This is unacceptable for
      # logging in a multi-process environment (e.g., unicorn), as these writes can be interlaced.
      # So instead, print a single string with explicit newline.
      if @console_print && severity >= @stderr_level
        STDERR.print((@stderr_logger_prefix || @use_logger_prefix ? ruby_logger_message : raw_message) + "\n")
        STDERR.flush # Only needed if STDERR has been reopened without auto-flush
      elsif @console_print && severity >= @stdout_level
        STDOUT.print((@stdout_logger_prefix || @use_logger_prefix ? ruby_logger_message : raw_message) + "\n")
        STDOUT.flush
      end

      @extra_loggers.each do |logger|
        logger.send(ruby_severity, @use_logger_prefix ? ruby_logger_message : raw_message) rescue nil
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

    # This isn't perfect.  "Real" Ruby loggers use << to mean
    # "write directly to the underlying store without adding
    # headers or other cruft".  That's meaningful for file
    # loggers, but not for syslog.
    def << (message)
      add(::Logger::INFO, message)
    end

    ##
    # Allows messages of a particular log level to be ignored temporarily.
    #
    # Can you say "Broken Windows"?

    def silence(temporary_level = ::Logger::ERROR)
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

  def FakeLogger
    Termite::LOGGER_MAP.each_key do |key|
      define_method(LOGGER_LEVEL_MAP[key]) do
        # Do nothing
      end
    end

    # Alias the other methods to a do-nothing method
    alias :add :error
    alias :<< :error
    alias :log :error
    alias :silence :error
    alias :add_logger :error

    # Read and write level
    attr_accessor :level

    # For now, don't read an Ecology, just mock out these accessors.

    def stdout_level
      4
    end

    def stderr_level
      2
    end

    def file_logger
      nil
    end
  end
end

module Termite
  module Thread
    def self.new(*args, &block)
      ::Thread.new do
        begin
          block.call
        rescue ::Exception
          if args[0].respond_to?(:warn)
            logger = args[0]
          else
            logger = ::Termite::Logger.new(*args)
          end
          logger.warn "Exception in thread: #{$!.message}"
          logger.warn "  Backtrace:\n#{$!.backtrace.join("\n")}"
        end
      end
    end
  end
end
