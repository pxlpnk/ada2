# encoding: utf-8

require "raccoon/version"

require 'celluloid'

require 'xmpp4r'
require 'xmpp4r/muc'

require 'yaml'


Celluloid.logger.level = Logger::DEBUG


class MUCCommands

  @commands = []
  def add_command(regex, &callback)
    # Add the command spec - used for parsing incoming commands.
    @commands << {
      :regex     => regex,
      :callback  => callback
    }
  end
end


class JabberClientMUC
  include Celluloid
  include Celluloid::Logger


  attr_accessor  :client, :bot

  def initialize(config)
    debug "Initializing jabber connection"

    # Jabber.debug = true

    self.client = Jabber::Client.new(Jabber::JID.new(config["jabber_id"]))
    self.client.connect
    self.client.auth(config["password"])

    self.client.send(Jabber::Presence.new.set_show(:chat).set_status('Your servant I am!'))

    self.client.ssl_verifycb = OpenSSL::SSL::VERIFY_NONE

    self.bot = Jabber::MUC::SimpleMUCClient.new(self.client)

    room = "#{config["muc_channel"]}/ADA2"
    info "joining: #{room}"

    self.bot.join(room)

    setup
  end


  def setup
    debug "Setting up"
    self.bot.on_join do |time, nick|
      print_line "#{nick} joined the chat."
    end

    self.bot.on_message do |ts, author, text|
      info "#{author}: #{text}"
      unless author == bot.nick
        bot.say text
      end
    end

    self.bot.on_subject do |time,nick,subject|
      print_line time, "*** (#{nick}) #{subject}"
    end
  end

  def print_line(line, time=nil)
      info line
  end

  def exit_muc(msg)
    info "Exiting bot!"

    self.bot.exit msg
    self.client.close
  end

end



module ADA2

  def self.run(config)
    if File.exist?( config)
      @config =  YAML::load( File.open(config) )
      jabber_config = @config["jabber"]
      jabber_supervisor = JabberClientMUC.supervise(jabber_config)

    else
      puts "No configuration given! config.yaml"
    end

    trap 'INT' do
      jabber = jabber_supervisor.actors.first
      jabber.exit_muc "Killed by god!"
      jabber_supervisor.terminate
      exit
    end
  end
end

if __FILE__ == $0
  config = ARGV[0]
  config ||= File.join "config.yml"
  ADA2.run(config)
  sleep
end
