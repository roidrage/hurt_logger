require 'em-hiredis'
require_relative '../hurt_logger'

class HurtLogger
  class Tail
    include Redis

    def run
      trap :INT do
        EM.stop
        exit
      end

      redis.subscribe(name)
      redis.on(:message) do |channel, message|
        puts message
      end
    end
  end
end

if ARGV[0] == 'tail'
  lM.run {HurtLogger::Tail.new.run}
end
