require "rubygems"
require "termite/version.rb"
require "multi_json"
require "syslog_logger"
require "thread"

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
  class Logger < SyslogLogger
    def initialize(logdev, shift_age = 0, shift_size = 1048576)
      Ecology.read

      super(Ecology.application)

      # SyslogLogger gets this wrong for inheritance, and
      # winds up setting Termite::Logger::SYSLOG but not
      # SyslogLogger::SYSLOG.  We'll fix its mistake.
      SyslogLogger.const_set :SYSLOG, SYSLOG
    end

    def add(priority, message, data, options = {})
      if options[:rate]
        # TODO(noah) do the sampling here and just exit with some % chance?
      end

      if data.is_a?(Hash)
        data = MultiJson.encode(data)
      end

      tid = Ecology.thread_id(Thread.current)

      sl_message = "[#{tid}]: #{message} #{data}"

      super(priority, sl_message)
    end
  end
end
