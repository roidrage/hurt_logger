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
      drain.should_not_receive(:send_data)
      receiver.drains << drain
      receiver.filters << "heroku.router"
      receiver.receive_data("heroku.router something something\n")
    end
  end
end
