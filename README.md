Termite
=======

Termite is a gem to handle local logs.  Specifically, it logs to
Syslog in a simple component-based manner, records thread IDs and
serializes JSON data.

It uses, but doesn't depend on, an Ecology file to specify things
like the default application name and other logging settings.

Installing
==========

"gem install termite" works pretty well.  You can also specify Termite
from a Gemfile if you're using Bundler (and you should).

Ooyalans should make sure that "gems.sv2" is listed as a gem source in
your Gemfile or on your gem command line.

Logging Dynamically
===================

Create a logger with something like:

  @logger = Termite::Logger.new

Then use it like a regular logger, possibly with options:

  @logger.add(Logger::DEBUG, "so, like, this thing happened, right?", {}, :component => :ValleyGirl)
  @logger.warn { "And I was like, whoah!" }

You can also pass in JSON data after your message and before your options:

  @logger.fatal("Pain and misery!", { :where_it_hurts => "elbow" }, :component => "WhinyLib")
  @logger.info("I ache", {:where_it_hurts => "kidney"}, :application => "NotMe", :component => "StoicLib")

Termite also supports full Ruby Logger initialize parameters for backward compatibility:

  @logger = Termite::Logger.new("/var/lib/daily_termite_logs", "daily")
  @logger = Termite::Logger.new("/tmp/rotatable.txt", 15, 1024000)  # Up to 15 logs of size 1024000

Translating to SysLog
=====================

Termite translates Ruby Logger severities into SysLog severities.  By default, this is the mapping:

Logger   => SysLog
:unknown => :alert
:fatal   => :crit
:error   => :err
:warn    => :warning
:info    => :info
:debug   => :debug

Configuring with an Ecology
===========================

Termite supports a standard Ecology file.  By default, it will look at the location of the current
executable ($0) with extension .ecology.  So "bob.rb" would have "bob.ecology" next to it.

An Ecology is a JSON file of roughly this structure:

{
  "application": "MyApp",
  "logging": {
    "default_component": "SplodgingLib",
    "extra_json_fields": {
      "app_group": "SuperSpiffyGroup",
      "precedence": 7
    },
    "console_print": "off",
    "filename": "/tmp/bobo.txt",
    "shift_age": 10,
    "shift_size": 1024000,
  }
}

Absolutely every part of it is optional, including the presence of the file at all.

You can override the application name, as shown above.  Other than the application name,
all Termite-specific parameters are under the "logging" field, as above.

The default_component is what application component is given for an add() call by default.
If set, it can be removed with ":component => nil" for a given add() call.

Extra JSON fields are added to the JSON data of every add() call.

Console_print can be set to "off" (or "no" or "0") to turn off Termite printing to stderr
and stdout by default at different log levels.

Filename, shift_age and shift_size are the same as Ruby Logger's normal initialize
parameters.  The first is the filename to log to, the second is how many total log files
to keep, and the third is how large each log file can grow.  Or the second can be set to
a value like "daily" or "monthly", and then the third is irrelevant.

Releasing within Ooyala
=======================

Ooyalans, to release Termite to gems.sv2, use the following:

  gem build
  rake _0.8.7_ -f ../ooyala_gems.rake gem:push termite-0.0.1.gem

Change the version to the actual version you'd like to push.
