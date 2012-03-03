Hurt Logger
===========

A pre-filtering tool for syslog messages. I wanted to have something simple
acting as a mediator, filtering out uninteresting log messages from a stream,
e.g. the log messages from Heroku's router, before they're aggregated into a
central logging solution like [Graylog](http://www.graylog2.org/),
[Papertrail](https://papertrailapp.com/) or [Loggly](http://loggly.com/). Even
with centralized logging, there's such a thing as too much noise. The function
is focused on simple string matching and forwarding to a number of syslog
drains. You can think of it as a logging multiplier too.

Installation
============

Unfortunately, without custom routing, you can't just run this on Heroku as it
requires TCP access. The Heroku router only allows you to send HTTP traffic.
There's a [nifty plugin](https://github.com/JacobVorreuter/heroku-routing) for
the Heroku cli tool to configure routing. Ask your local Heroku representative
for more details, but don't tell them I sent you.

In any way, clone the repo, run `bundle exec lib/hurt_logger.rb <port>`.

License
=======

BSD. (c) 2012 Mathias Meyer

[![Travis Build Status](https://secure.travis-ci.org/mattmatt/hurt_logger.png)](https://secure.travis-ci.org/mattmatt/hurt_logger)
