require 'bundler'
Bundler.setup

require 'eventmachine'
require 'uri'

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
    connect_to_drains

    EventMachine.start_server('0.0.0.0', options[:port], Receiver) do |receiver|
      receiver.filters = options[:filters]       
    end
  end

  def setup
    trap :INT do
      EM.stop
      exit
    end
  end

  def extract_from_uri(uri)
    uri = URI.parse(uri)
    [uri.host, uri.port]
  end

  def connect_to_drains
    options[:drains].each do |drain|
      host, port = extract_from_uri(drain)
      next if host.nil? or port.nil?
      EventMachine.connect(host, port, Drain)
    end
  end

  class Receiver < EventMachine::Connection
    attr_reader :data
    attr_accessor :drains, :filters

    def initialize(*args)
      super
      @drains = @filters = []
    end

    def post_init
      @data = ""
    end

    def receive_data(data)
      @data << data
      if @data[-1] == "\n"
        maybe_publish(@data)
        @data = ""
      end
    end

    def maybe_publish(data)
      return if filters_match?(data)
      drains.each {|drain| drain.send_data(data)}
    end

    def filters_match?(data)
      filters.any? do |filter|
        data.match(/#{filter}/)
      end
    end
  end

  class Drain < EventMachine::Connection
  end
end

if ARGV[0]
  HurtLogger.new.run(port: ARGV[0])
end
