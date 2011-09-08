require "rubygems"
require "termite/version.rb"
require "multi_json"
require "thread"
require "syslog"
require "logger"
require "socket"

module Ecology
  class << self
    attr_accessor :application
    attr_accessor :mutex
  end

  ECOLOGY_EXTENSION = ".ecology"

  Ecology.mutex = Mutex.new

  # Normally this is only for testing.
  def self.reset
    Ecology.application = nil
    @ecology_data = nil
    @ecology_initialized = nil
  end

  def self.read(ecology_pathname = nil)
    return if @ecology_initialized

    Ecology.mutex.synchronize {
      file_path = ENV['ECOLOGY_SPEC'] || ecology_pathname || default_ecology_name
      if File.exist?(file_path)
        contents = File.read(file_path)
        @ecology_data = MultiJson.decode(contents);

        Ecology.application = @ecology_data["application"] || File.basename($0)
      else
        Ecology.application = File.basename($0)
      end
    }

    @ecology_initialized = true
  end

  def self.default_ecology_name(executable = $0)
    suffix = File.extname(executable)
    executable[0..(executable.length - 1 - suffix.size)] +
      ECOLOGY_EXTENSION
  end

  # This is a convenience function because the Ruby
  # thread API has no accessor for the thread ID,
  # but includes it in "to_s" (buh?)
  def self.thread_id(thread)
    return "main" if thread == Thread.main

    str = thread.to_s

    match = nil
    match  = str.match /(0x\d+)/
    return nil unless match
    match[1]
  end
end

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
    attr_reader :file_logger

    def initialize(logdev = nil, shift_age = 0, shift_size = 1048576, options = {})
      options = logdev if(logdev.is_a?(Hash))

      Ecology.read

      @application = Ecology.application
      @level = ::Logger::DEBUG

      @extra_loggers = []
      file_logger = ::Logger.new(logdev, shift_age, shift_size) if logdev
      @extra_loggers << file_logger if logdev

      # For UDP socket
      @server_addr = options[:address] || "0.0.0.0"
      @server_port = options[:port] ? options[:port].to_i : 514

      @@sockets ||= {}
      key = "#{@server_addr}:#{@server_port}"
      @@sockets[key] ||= UDPSocket.new
      @socket = @@sockets[key]
    end

    def add_logger(logger)
      @extra_loggers << logger
    end

    def socket
      @socket
    end

    def add(severity, message = nil, data = nil, options = {}, &block)
      severity ||= ::Logger::UNKNOWN
      return true if severity < @level

      application = options[:application] || @application
      if options[:component]
        application += ":" + options[:component]
      end

      if data.is_a?(Hash)
        data = MultiJson.encode(data)
      end

      tid = Ecology.thread_id(Thread.current)
      time = Time.now
      day = time.strftime("%b %d").sub(/0(\d)/, ' \\1')
      time_of_day = time.strftime("%T")
      hostname = Socket.gethostname
      tag = Syslog::LOG_LOCAL6 + SYSLOG_SEVERITY_MAP[LEVEL_LOGGER_MAP[severity]]

      syslog_string = "<#{tag}>#{day} #{time_of_day} #{hostname} #{application} [#{Process.pid}]: "
      syslog_string += "[#{tid}] #{clean(message || block.call)} #{data}"
      @socket.send(syslog_string, 0, @server_addr, @server_port)

      ruby_severity = LOGGER_LEVEL_MAP.invert[severity]
      @extra_loggers.each do |logger|
        logger.send(ruby_severity, syslog_string)
      end

      true
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
