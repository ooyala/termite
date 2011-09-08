#!/usr/bin/env ruby
require "rubygems"
require "termite"

logger = Termite::Logger.new
logger.fatal("Test logging from log_locally.rb!")
