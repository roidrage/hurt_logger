require 'bundler'
Bundler.setup

require 'eventmachine'
require 'uri'

class HurtLogger
  @@defaults = {
    port: 11521,
    drains: [],
    filters: []
  }
  attr_reader :options, :drains, :receiver

  def options=(options)
    @options = @@defaults.merge(options)
  end

  def initialize
    @drains = []
  end

  def run(config = {})
    self.options = config
    extract_drains
    extract_filters
    setup
    connect_to_drains
    start_server
  end

  def extract_drains
    (ENV['HURTLOGGER_DRAINS'] || "").split(',').each do |drain|
      options[:drains] << drain
    end
  end

  def extract_filters
    (ENV['HURTLOGGER_FILTERS'] || "").split(',').each do |filter|
      options[:filters] << filter
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
      EventMachine.connect(host, port, Drain) do |client|
        drains << client
      end
    end
  end

  def start_server
    EventMachine.start_server('0.0.0.0', options[:port], Receiver) do |receiver|
      puts "Listening on port #{options[:port]}"
      receiver.filters = options[:filters]
      receiver.drains << RedisDrain.new
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

  module Redis
    def redis
      @redis ||= EM::Hiredis.connect(ENV['REDISTOGO_URL'])
    end

    def name
      "hurt_logger.recent_logs"
    end
  end

  class RedisDrain
    include HurtLogger::Redis
    def publish(line)
      redis.publish(name, line)
    end
  end
end

if ARGV[0] == "run"
  EM.run { HurtLogger.new.run(port: ARGV[1]) }
end
