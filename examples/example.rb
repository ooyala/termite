$LOAD_PATH << "../termite_gem/lib"
require "termite.rb"

Ecology.read("./example.ecology")
logger = Termite::Logger.new

while true
  logger.debug("a")
  sleep 0.1
  logger.info("b")
  sleep 0.1
  logger.warn("c")
  sleep 0.1
  logger.error("d")
  sleep 0.1
  logger.fatal("e")
  sleep 0.1
  logger.unknown("f")
  sleep 0.1
end
