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
      receiver.drains << RedisDrain.new
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
      @drains = []
      @filters = []
    end

    def post_init
      @data = ""
    end

    def receive_data(data)
      data.split(/(.*)\r?\n/).each do |line|
        next if line.empty?
        maybe_publish(line)
      end
    end

    def maybe_publish(data)
      return if filters_match?(data)
      drains.each {|drain| drain.publish(data)}
    end

    def filters_match?(data)
      filters.any? do |filter|
        data.match(/#{filter}/)
      end
    end
  end

  class Drain < EventMachine::Connection
    def publish(line)
      send_data(line)
    end
  end

  class RedisDrain
    def redis
      @@redis ||= EM::Hiredis.connect(ENV['REDISTOGO_URL'])
    end

    def name
      "hurt_logger.recent_logs"
    end

    def publish(line)
      redis.publish(name, line)
    end
  end
end
