$LOAD_PATH << "../termite_gem/lib"
require "termite.rb"

Ecology.read("./example.ecology")
logger = Termite::Logger.new

while true
  logger.debug("debug message!")
  sleep 0.1
  logger.info("info message!")
  sleep 0.1
  logger.warn("warning message!")
  sleep 0.1
  logger.error("error message!")
  sleep 0.1
  logger.fatal("fatal message!")
  sleep 0.1
  logger.unknown("Unknown priority message!")
  sleep 0.1
end
