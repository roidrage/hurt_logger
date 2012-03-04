require 'spec_helper'
require 'hurt_logger'

describe HurtLogger do
  describe "extracting host and port from a syslog uri" do
    let(:logger) {HurtLogger.new}

    it "should parse syslog drains" do
      host, port = logger.extract_from_uri("syslog://logs.papertrailapp.com:12345")
      host.should == "logs.papertrailapp.com"
      port.should == 12345
    end

    it "should ignore borked urls" do
      host, port = logger.extract_from_uri("adsfjfkljsdfklajsf;s")
      host.should == nil
      port.should == nil
    end
  end

  describe "connecting to drains" do
    let(:logger) {HurtLogger.new}

    it "should connect to valid drains" do
      logger.options = {drains: ['syslog://logs.papertrailapp.com:12345']}
      EM.should_receive(:connect).with("logs.papertrailapp.com", 12345, HurtLogger::Drain)
      logger.connect_to_drains
    end

    it "shouldn't connect to invalid drains" do
      logger.options = {drains: ['asfasof;safj;akfjsj;']}
      EM.should_not_receive(:connect)
      logger.connect_to_drains
    end
  end
end

describe HurtLogger::Receiver do
  let(:receiver) { HurtLogger::Receiver.new nil }

  describe "when receiving data" do
    it "should split the lines and publish every single line" do
      receiver.should_receive(:maybe_publish).twice
      receiver.receive_data("hello\nworld")
    end
  end

  describe "when publishing data" do
    let(:drain) { HurtLogger::Drain.new nil }
    let(:receiver) { HurtLogger::Receiver.new nil }

    it "shouldn't publish when a filter matched" do
      drain.should_not_receive(:publish)
      receiver.drains << drain
      receiver.filters << "heroku.router"
      receiver.receive_data("heroku.router something something\n")
    end

    it "should publish to the drain when the filter didn't match" do
      drain.should_receive(:publish)
      receiver.drains << drain
      receiver.filters << "heroku.router"
      receiver.receive_data("heroku.nginx\n")
    end

    describe "locally publishing log entries" do
      it "should publish to the redis drain" do
        EM.run {
          receiver.drains << HurtLogger::RedisDrain.new
          HurtLogger::RedisDrain.any_instance.should_receive(:publish)
          receiver.receive_data("heroku\n")
          EM.stop
        }
      end
    end
  end

  describe "running the server" do
    before do
      ENV['HURTLOGGER_DRAINS'] = nil
      ENV['HURTLOGGER_FILTERS'] = nil
    end

    it "should create a server" do
      EM.should_receive(:start_server)
      HurtLogger.new.run
    end

    it "should connect to drains based on ENV" do
      EM.run {
        ENV['HURTLOGGER_DRAINS'] = 'syslog://logs.papertrailapp.com:54321'
        EM.should_receive(:connect).with 'logs.papertrailapp.com', 54321, HurtLogger::Drain
        HurtLogger.new.run
        EM.stop
      }
    end

    it "should add filters from ENV" do
      EM.run {
        ENV['HURTLOGGER_FILTERS'] = 'heroku.router,heroku.nginx'
        logger = HurtLogger.new
        logger.run
        logger.options[:filters].should include("heroku.router")
        EM.stop
      }
    end
  end
end
