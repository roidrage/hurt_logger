require 'em-hiredis'
require_relative '../hurt_logger'

class HurtLogger
  class Tail
    include Redis

    def run
      %w{INT TERM QUIT}.each {|signal|
        trap signal do
          EM.stop
          exit
        end
      }

      redis.subscribe(name)
      puts "Listening for messages..."
      redis.on(:message) do |channel, message|
        puts message
      end
    end
  end
end

if ARGV[0] == 'tail'
  EM.run {HurtLogger::Tail.new.run}
end
