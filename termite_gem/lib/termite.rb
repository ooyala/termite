require "rubygems"
require "termite/hastur_logger"
require "termite/syslog_logger"
require "termite/version"

require "ecology"
require "multi_json"
require "rainbow"

require "thread"
require "syslog"
require "logger"
require "socket"

module Termite
  class Logger
    ##
    # Maps Logger severities to syslog(3) severities.

    LOGGER_SYSLOG_MAP = {
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
    # Maps Ruby Logger log levels to their numerical values.

    LOGGER_LEVEL_MAP = {}

    LOGGER_SYSLOG_MAP.each_key do |key|
      LOGGER_LEVEL_MAP[key] = ::Logger.const_get key.to_s.upcase
    end

    ##
    # Maps Logger numerical log level values to syslog level names.

    LEVEL_SYSLOG_MAP = {}

    LOGGER_LEVEL_MAP.invert.each do |level, severity|
      LEVEL_SYSLOG_MAP[level] = LOGGER_SYSLOG_MAP[severity]
    end

    ##
    # Maps Syslog level names to their numerical severity levels

    SYSLOG_SEVERITY_MAP = {}

    LOGGER_SYSLOG_MAP.values.each do |syslog_severity|
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

    LOGGER_SYSLOG_MAP.each_key do |level|
      make_methods level
    end

    ##
    # Log level for Logger compatibility.

    attr_accessor :level
    attr_reader :stdout_level
    attr_reader :stderr_level

    def initialize(logdev = nil, shift_age = nil, shift_size = nil, options = {})
      if logdev.is_a?(Hash)
        options = logdev
        logdev = nil
      end

      @loggers ||= []
      @log_filename ||= logdev
      @shift_age ||= shift_age
      @shift_size ||= shift_size

      Ecology.read
      read_ecology_data(options)
    end

    private

    def read_ecology_data(options = {})
      @application = Ecology.application
      @default_component = options[:component] || Ecology.property("logging::default_component") ||
        options[:default_component]
      # @console_print defaults to "yes", but can be nil if "no", "off" or "0" is specified
      @console_print = Ecology.property("logging::console_print") || options[:console_print] || "yes"
      @console_print = nil if ["no", "off", "0"].include?(@console_print)
      @default_fields = Ecology.property("logging::extra_json_fields") || options[:extra_json_fields] || {}
      @use_logger_prefix = Ecology.property("logging::use_logger_prefix") || options[:use_logger_prefix]
      @level = Ecology.property("logging::level") || options[:level]
      @level = string_to_severity(@level) if @level
      @level ||= ::Logger::DEBUG

      sinks = Ecology.property("logging::sinks")
      sinks ? instantiate_sinks(sinks, options) : read_unsinked_ecology(options)
    end

    # This is the codepath for ecology files that do not have a 'sinks' section defined
    def read_unsinked_ecology(options)
      sinks = []
      # File Sink
      file_sink = {"type" => "file", "min_level" => @level}
      file_sink["filename"] = Ecology.property("logging::filename", :as => :path) ||
        options[:logging_filename]
      file_sink["shift_age"] = Ecology.property("logging::shift_age") || options[:shift_age]
      file_sink["shift_size"] = Ecology.property("logging::shift_size") || options[:shift_size]
      file_sink["logger_prefix?"] = @use_logger_prefix if @use_logger_prefix
      sinks << file_sink if file_sink["filename"]

      # STDERR Sink
      stderr_sink = {"type" => "file", "filename" => STDERR}
      @stderr_level = Ecology.property("logging::stderr_level") || options[:stderr_level] || ::Logger::ERROR
      stderr_sink["min_level"] = string_to_severity(@stderr_level) if @stderr_level
      if @use_logger_prefix
        stderr_sink["logger_prefix?"] = @use_logger_prefix
      else
        stderr_prefix = Ecology.property("logging::stderr_logger_prefix") || options[:stderr_logger_prefix]
        stderr_sink["logger_prefix?"] = stderr_prefix if stderr_prefix
      end
      stderr_sink["color"] = Ecology.property("logging::stderr_color") || options[:stderr_color]
      stderr_sink["color"] ||= "red" if STDERR.tty?
      sinks << stderr_sink if @console_print

      # STDOUT Sink
      stdout_sink = {"type" => "file", "filename" => STDOUT}
      @stdout_level = Ecology.property("logging::stdout_level") || options[:stdout_level] || ::Logger::INFO
      stdout_sink["min_level"] = string_to_severity(@stdout_level) if @stdout_level
      stdout_sink["max_level"] = string_to_severity(@stderr_level) - 1
      if @use_logger_prefix
        stdout_sink["logger_prefix?"] = @use_logger_prefix
      else
        stdout_prefix = Ecology.property("logging::stdout_logger_prefix") || options[:stdout_logger_prefix]
        stdout_sink["logger_prefix?"] = stdout_prefix if stdout_prefix
      end
      stdout_sink["color"] = Ecology.property("logging:stdout_color") || options[:stdout_color]
      stdout_sink["color"] ||= "blue" if STDOUT.tty?
      sinks << stdout_sink if @console_print

      # Syslog Sink
      syslog_sink = {"type" => "syslog"}
      syslog_sink["transport"] = Ecology.property("logging::transport") || options[:transport]
      sinks << syslog_sink


      # Set up sinks
      instantiate_sinks(sinks, options)
    end

    # For each sink, and to loggers
    def instantiate_sinks(sinks, options)
      sinks = sinks.dup
      syslog = false
      # Maximum Level
      min_level = 5
      sinks.each do |sink|
        # Set min level if lower than current (@level if not defined)
        if sink["min_level"]
          sink_level = string_to_severity(sink["min_level"])
          min_level = sink_level if sink_level < min_level
        else min_level = @level
        end
        cur_logger = case sink["type"]
          when "file"
            sink["newline?"] = true unless sink.has_key? "newline?"
            case sink["filename"]
              when STDOUT
                ::Logger.new(STDOUT) if @console_print
              when STDERR
                ::Logger.new(STDERR) if @console_print
              else
                ::Logger.new(sink["filename"], sink["shift_age"] || 0, sink["shift_size"] || 1048576)
            end
          when "stdout"
            sink["newline?"] = true unless sink.has_key? "newline?"
            ::Logger.new(STDOUT) if @console_print
          when "stderr"
            sink["newline?"] = true unless sink.has_key? "newline?"
            ::Logger.new(STDERR) if @console_print
          when "syslog"
            syslog = true
            setup_syslog_logger(sink, options)
          when "hastur"
            setup_hastur_logger(sink, options)
        end
        sink["logger"] = cur_logger
      end
      @loggers = sinks

      # Create syslog logger if not defined in sinks
      unless syslog
        min_level = @level
        add_logger(setup_syslog_logger(options), "type" => "syslog", "min_level" => min_level)
      end

      # Constructor params logger
      if @log_filename
        min_level = @level
        add_logger(::Logger.new(@log_filename, @shift_age || 0, @shift_size || 1048576), "type" => "file",
          "filename" => @log_filename,
          "shift_age" => @shift_age || 0,
          "shift_size" => @shift_size || 1048576,
          "logger_prefix?" => @use_logger_prefix,
          "min_level" => @level
        )
      end
      # If the min level of all loggers is greater than @level, use that
      @level = [@level, min_level].max
    end

    def string_to_severity(str)
      return str if str.is_a? Numeric
      orig_string = str
      str = str.strip.downcase
      return str.to_i if str =~ /\d+/
      ret = LOGGER_LEVEL_MAP[str.to_sym]
      raise "Unknown logger severity #{orig_string}" unless ret
      ret
    end

    def setup_syslog_logger(sink, options)
      # For UDP socket
      @server_addr = options[:address] || "0.0.0.0"
      @server_port = options[:port] ? options[:port].to_i : 514
      @socket = find_or_create_socket(@server_addr, @server_port)
      SyslogLogger.new(@socket, @server_addr, @server_port, sink["transport"])
    end

    def setup_hastur_logger(sink, options)
      @hastur_addr = options[:hastur_address] || "127.0.0.1"
      @hastur_port = sink["udp_port"] || options[:hastur_port] || 8125
      @hastur_socket = find_or_create_socket(@hastur_addr, @hastur_port)
      HasturLogger.new(@hastur_socket, @hastur_addr, @hastur_port, sink["labels"])
    end

    def find_or_create_socket(addr, port)
      @@sockets ||= {}
      key = "#{addr}:#{port}"
      @@sockets[key] ||= UDPSocket.new
    end

    public

    def add_logger(logger, options={})
      if logger.is_a? Hash
        @loggers << logger
      else
        options["logger"] = logger
        @loggers << options
      end
    end

    def socket
      @socket
    end

    COLORS = [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white, :default]

    def raw_add(severity, raw_message = nil, data = nil, options = {}, &block)
      # Severity is a numerical severity using Ruby Logger's scale
      severity ||= ::Logger::UNKNOWN
      return true if severity < @level

      application =  options[:application] || @application
      component = @default_component
      component = options[:component] if options.has_key?(:component)

      combined_app = application + ":" + component if component
      app_data = {:combined => combined_app, :app => application, :component => component}

      data ||= {}
      if data.is_a?(Hash)
        data = @default_fields.merge(data)
        data = MultiJson.dump(data)
      elsif data.is_a?(String)
        # Can't merge a JSON string with default data
        raise "Can't merge a JSON string with extra fields!" unless @default_fields.empty?
      else
        raise "Unknown data object passed as JSON!"
      end

      time = Time.now
      full_message = clean(raw_message || block.call)

      # Lifted from Logger::Formatter
      ruby_logger_severity = RUBY_LOGGER_SEV_LABELS[severity]
      ruby_logger_message = "%s, [%s#%d] %5s -- %s: %s" % [ruby_logger_severity[0..0],
          (time.strftime("%Y-%m-%dT%H:%M:%S.") << "%06d " % time.usec),
          $$, ruby_logger_severity, "", full_message]

      @loggers.each do |sink|
        next if (sink["min_level"] && severity < string_to_severity(sink["min_level"])) ||
          (sink["max_level"] && severity > string_to_severity(sink["max_level"])) ||
          sink["logger"].nil?
        message = sink["logger_prefix?"] ? ruby_logger_message : full_message
        message += " #{data}" if sink["logger_data?"]
        if sink["logger"].respond_to?(:send_message)
          sink["logger"].send_message(severity, message, app_data, time, data)
        else
          message += "\n" if sink["newline?"] && sink["newline?"] != "false"
          if sink["color"]
            color = (COLORS.include? sink["color"].to_sym) ? sink["color"].to_sym : sink["color"]
            message = message.color(color)
          end
          sink["logger"] << message
        end rescue nil
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
    Termite::LOGGER_SYSLOG_MAP.each_key do |key|
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
