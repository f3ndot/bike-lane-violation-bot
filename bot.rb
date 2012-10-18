#!/usr/bin/env ruby
require 'rubygems'

require 'colorize'
require 'yaml'

APP_HUMAN_NAME = 'Bike Lane Violations'
APP_NAME = 'bike-lane-violation-bot'
APP_VERSION = '0.1.0'

MYBIKELANE_API_BASE_URL = 'http://www.mybikelane.com/api/'

config = YAML.load_file('config.yml')

def write_config_to_file(obj)
  output = File.new 'config.yml', 'w'
  output.puts YAML.dump(obj)
  output.close
end

if config['oauth']['token'].nil? or config['oauth']['token_secret'].nil?
  require 'oauth'

  puts "
    ############################################
    ##                                        ##
    ##          A T T E N T I O N !           ##
    ##  ------------------------------------  ##
    ##  This application needs to register    ##
    ##  with Twitter's OAuth. Visit the       ##
    ##  following URL with the user you want  ##
    ##  this bot to tweet from signed in.     ##
    ##                                        ##
    ##  You must authoize the application     ##
    ##  and enter in the PIN code displayed   ##
    ##  On your screen.                       ##
    ##                                        ##
    ############################################

  ".red

  consumer = OAuth::Consumer.new(config['oauth']['consumer_key'], config['oauth']['consumer_secret'], :site => "http://twitter.com")
   
  request_token = consumer.get_request_token 
  print "AUTHORIZATION URL: ".yellow
  puts "#{request_token.authorize_url}".light_white
  print "ENTER PIN: ".yellow
  oauth_verifier = gets.strip

  puts "\nGenerating access credentials...".yellow

  access_token = request_token.get_access_token(:oauth_verifier => oauth_verifier )
  config['oauth']['token'] = access_token.token
  config['oauth']['token_secret'] = access_token.secret
  if access_token.token and access_token.secret
    puts "Successfully generated OAuth screts!".green
  end

  puts "Writing OAuth config to YAML file...".green

  write_config_to_file config
  puts "Success! Done! The bot is ready to use! Booting main loop now\n\n".green
end

require 'date'
require 'twitter'
require 'net/http'
require 'open-uri'
# require 'nokogiri'
require 'xmlsimple'

Twitter.configure do |t_config|
  t_config.consumer_key = config['oauth']['consumer_key']
  t_config.consumer_secret = config['oauth']['consumer_secret']
  t_config.oauth_token = config['oauth']['token']
  t_config.oauth_token_secret = config['oauth']['token_secret']
end

puts "#{APP_HUMAN_NAME} v.#{APP_VERSION} Booted!\n".green


puts "Making MyBikeLane API Call...".yellow
begin
  # records = XmlSimple.xml_in(Net::HTTP.get_response(URI("#{MYBIKELANE_API_BASE_URL}/posts?city_id=39&format=xml")).body)
  records = XmlSimple.xml_in('test-data.xml')
  records['record'].sort! { |a, b|  a['id'] <=> b['id'] }
  records['record'].each do |record|
    if config['last_id_tweeted'].nil? or record['id'].first > config['last_id_tweeted'] 
      puts "Title: #{record['occurred-at']}"
      config['last_id_tweeted'] = record['id'].first
    else
      puts "Ignoring ID: #{record['occurred-at']}"
    end
  end
  write_config_to_file config
rescue Exception => e
  puts "\033[1mMyBikeLane API call FAILED:\033[22m #{e.message}".red
else
  puts "Got API response OK!".green
end

# Twitter.update 'Testing Ruby-powered tweet! Holla at @f3ndot'