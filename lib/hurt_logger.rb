require 'bundler'
Bundler.setup

require 'eventmachine'

class HurtLogger
  @@defaults = {
    port: 80,
    drains: [],
    filters: []
  }
  attr_reader :options

  def options=(options)
    @options = @@defaults.merge(options)
  end

  def run(config = {})
    self.options = config

    setup
    EventMachine.run {
      EventMachine.start_server '0.0.0.0', options[:port], Receiver
    }
  end

  def setup
    trap :INT do
      EM.stop
      exit
    end
  end

  class Receiver < EventMachine::Connection
    def post_init
    end

    def receive_data(data)
    end
  end

  class Drain < EventMachine::Connection
  end
end

if ARGV[0]
  HurtLogger.new.run(port: ARGV[0])
end
