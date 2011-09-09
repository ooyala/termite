Termite
=======

Termite is a gem to handle local logs.  Specifically, it logs to
Syslog in a simple component-based manner, records thread IDs and
serializes JSON data.

It uses, but doesn't depend on, an Ecology file to specify things
like the default application name.

Releasing within Ooyala
=======================

To release Termite to gems.sv2, use the following:

  gem build
  rake _0.8.7_ -f ../ooyala_gems.rake gem:push termite-0.0.1.gem

Obviously, change the version to the actual version you'd like to push.
