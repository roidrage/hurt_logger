require 'em-hiredis'
require 'hurt_logger'

class HurtLogger
  class Tail
    include Redis

    def run
      redis.subscribe(name)
      redis.on(:message) do |channel, message|
        puts message
      end
    end
  end
end
