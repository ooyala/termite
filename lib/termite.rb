require "rubygems"
require "termite/version.rb"
require "multi_json"
require "thread"
require "syslog"
require "logger"

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

  def self.read
    return if @ecology_initialized

    Ecology.mutex.synchronize {
      file_path = ENV['TERMITE_ECOLOGY'] || default_ecology_name
      contents = File.read(file_path)
      @ecology_data = MultiJson.decode(contents);

      Ecology.application = @ecology_data["application"]
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
    # Maps Logger warning types to syslog(3) warning types.

    LOGGER_MAP = {
      :unknown => :alert,
      :fatal   => :err,
      :error   => :warning,
      :warn    => :notice,
      :info    => :info,
      :debug   => :debug,
    }

    ##
    # Maps Logger log levels to their values so we can silence.

    LOGGER_LEVEL_MAP = {}

    LOGGER_MAP.each_key do |key|
      LOGGER_LEVEL_MAP[key] = ::Logger.const_get key.to_s.upcase
    end

    ##
    # Maps Logger log level values to syslog log levels.

    LEVEL_LOGGER_MAP = {}

    LOGGER_LEVEL_MAP.invert.each do |level, severity|
      LEVEL_LOGGER_MAP[level] = LOGGER_MAP[severity]
    end

    ##
    # Builds a methods for level +meth+.

    def self.make_methods(meth)
      eval <<-EOM, nil, __FILE__, __LINE__ + 1
        def #{meth}(message = nil, &block)
          return true if #{LOGGER_LEVEL_MAP[meth]} < @level
          add(::Logger::#{meth.to_s.upcase}, message, &block)
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
    attr_accessor :file_logger

    def initialize(logdev = nil, shift_age = 0, shift_size = 1048576)
      Ecology.read

      @level = ::Logger::DEBUG

      @file_logger = ::Logger.new(logdev, shift_age, shift_size) if logdev

      return if defined? SYSLOG
      log_object = Syslog.open(Ecology.application, Syslog::LOG_PID | Syslog::LOG_CONS,
                               Syslog::LOG_LOCAL7)
      Termite::Logger.const_set :SYSLOG, log_object
    end

    def add(severity, message = nil, data = nil, options = {}, &block)
      severity ||= ::Logger::UNKNOWN
      return true if severity < @level

      if options[:rate]
        # TODO(noah) do the sampling here and just exit with some % chance?
      end

      if data.is_a?(Hash)
        data = MultiJson.encode(data)
      end

      tid = Ecology.thread_id(Thread.current)

      sl_message = "[#{tid}]: #{clean(message || block.call)} #{data}"

      SYSLOG.send LEVEL_LOGGER_MAP[severity], sl_message
      @file_logger.send(LEVEL_LOGGER_MAP[severity], sl_message) if @file_logger

      true
    end

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
      message.gsub!(/%/, '%%') # syslog(3) freaks on % (printf)
      message.gsub!(/\e\[[^m]*m/, '') # remove useless ansi color codes
      return message
    end
  end
end
