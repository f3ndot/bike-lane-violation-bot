#!/usr/bin/env ruby
require 'rubygems'

require 'colorize'
require 'yaml'

APP_HUMAN_NAME = 'Bike Lane Violations'
APP_NAME = 'bike-lane-violation-bot'
APP_VERSION = '0.1.0'

secrets = YAML.load_file('secrets.yml')

if secrets['oauth']['token'].nil? or secrets['oauth']['token_secret'].nil?
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

  consumer = OAuth::Consumer.new(secrets['oauth']['consumer_key'], secrets['oauth']['consumer_secret'], :site => "http://twitter.com")
   
  request_token = consumer.get_request_token 
  print "AUTHORIZATION URL: ".yellow
  puts "#{request_token.authorize_url}".light_white
  print "ENTER PIN: ".yellow
  oauth_verifier = gets.strip

  puts "\nGenerating access credentials...".yellow

  access_token = request_token.get_access_token(:oauth_verifier => oauth_verifier )
  secrets['oauth']['token'] = access_token.token
  secrets['oauth']['token_secret'] = access_token.secret
  if access_token.token and access_token.secret
    puts "Successfully generated OAuth screts!".green
  end

  puts "Writing OAuth secrets to YAML file...".green

  output = File.new 'secrets.yml', 'w'
  output.puts YAML.dump(secrets)
  output.close
  puts "Success! Done! The bot is ready to use! Booting main loop now\n\n".green
end

require 'twitter'
require 'net/http'
require 'open-uri'
require 'nokogiri'

puts "#{APP_HUMAN_NAME} v.#{APP_VERSION} Booted!\n".green

Twitter.configure do |config|
  config.consumer_key = secrets['oauth']['consumer_key']
  config.consumer_secret = secrets['oauth']['consumer_secret']
  config.oauth_token = secrets['oauth']['token']
  config.oauth_token_secret = secrets['oauth']['token_secret']
end




# Twitter.update 'Testing Ruby-powered tweet! Holla at @f3ndot'