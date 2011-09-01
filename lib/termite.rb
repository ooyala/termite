require "rubygems"
require "termite/version.rb"
require "multi_json"
require "syslog_logger"
require "thread"

module Termite
  class << self
    attr_accessor :application
    attr_accessor :mutex
  end

  MANIFEST_EXTENSION = ".fj"

  Termite.mutex = Mutex.new

  # Normally this is only for testing.
  def self.reset
    Termite.application = nil
    @termite_data = nil
    @termite_initialized = nil
  end

  def self.read_manifest
    return if @termite_initialized

    Termite.mutex.synchronize {
      file_path = ENV['TERMITE_MANIFEST'] || default_manifest_name
      contents = File.read(file_path)
      @termite_data = MultiJson.decode(contents);

      Termite.application = @termite_data["application"]
    }

    @termite_initialized = true
  end

  def self.default_manifest_name(executable = $0)
    suffix = File.extname(executable)
    executable[0..(executable.length - 1 - suffix.size)] +
      MANIFEST_EXTENSION
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

  class Logger < SyslogLogger
    def initialize
      Termite.read_manifest

      super(Termite.application)

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

      tid = Termite.thread_id(Thread.current)

      sl_message = "[#{tid}]: #{message} #{data}"

      super(priority, sl_message)
    end
  end
end
