#!/usr/bin/env ruby
require 'rubygems'

require 'colorize'
require 'yaml'

APP_HUMAN_NAME = 'Bike Lane Violations'
APP_NAME = 'bike-lane-violation-bot'
APP_VERSION = '0.1.0'

MYBIKELANE_API_BASE_URL = 'http://www.mybikelane.com/api/'

MAX_ATTEMPTS = 3

config = YAML.load_file('config.yml')

def write_config_to_file(obj)
  output = File.new 'config.yml', 'w'
  output.puts YAML.dump(obj)
  output.close
end

def fire_tweet(status)
  num_attempts = 0
  begin
    num_attempts += 1
    Twitter.update status
    puts status.to_s.green
  rescue Twitter::Error::TooManyRequests => error
    if num_attempts <= MAX_ATTEMPTS
      # NOTE: Your process could go to sleep for up to 15 minutes but if you
      # retry any sooner, it will almost certainly fail with the same exception.
      puts "MAX_ATTEMPTS SLEEPING".cyan
      sleep error.rate_limit.reset_in
      retry
    else
      raise
    end
  end
end

# Do a check for OAuth. If not, fire the little wizzard
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

# Set up the OAuth for this run
Twitter.configure do |t_config|
  t_config.consumer_key = config['oauth']['consumer_key']
  t_config.consumer_secret = config['oauth']['consumer_secret']
  t_config.oauth_token = config['oauth']['token']
  t_config.oauth_token_secret = config['oauth']['token_secret']
end

puts "#{APP_HUMAN_NAME} v.#{APP_VERSION} Booted!\n".green

# Update once a day
if config['twitter_configuration']['last_updated'].nil? or config['twitter_configuration']['last_updated'] < Time.now.to_date.to_s
  puts "Updating stale Twitter configuration...".yellow
  
  t_config = Twitter.configuration
  config['twitter_configuration']['short_url_length_https'] = t_config['short_url_length_https']
  config['twitter_configuration']['short_url_length'] = t_config['short_url_length']
  config['twitter_configuration']['last_updated'] = Time.now.to_date.to_s

  puts "Updated Twitter configuration!".green
end

# Grab the violation data
loop do
  config = YAML.load_file('config.yml')
  puts "Making MyBikeLane API Call...".yellow
  begin
    records = XmlSimple.xml_in(Net::HTTP.get_response(URI("http://www.mybikelane.com/api/posts?city_id=39&format=xml")).body)
    # records = XmlSimple.xml_in('test-data.xml')
    # Sort the retrieved data in increasing order
    records['record'].sort! { |a, b|  a['id'] <=> b['id'] }
    records['record'].each do |record|
      # Only allow records that are "later" than the last tweeted records to be, well, tweeted
      if config['ignore_tweet_id_cache'] == true or config['last_id_tweeted'].nil? or record['id'].first > config['last_id_tweeted'] 

        title_string = "#{record['title'].first} "
        location_string = "(#{record['location'].first}) "
        hashtag_string = '#BikeTO '
        
        character_space = 140
        character_space -= [record['url'].first.length, config['twitter_configuration']['short_url_length']].min
        character_space -= hashtag_string.length
        character_space -= location_string.length

        remaining_space = character_space - title_string.length

        if remaining_space <= 0
          title_string = "#{title_string[0..(remaining_space.abs+'...'.length)]}... "
        end

        fire_tweet "#{title_string}#{location_string}#{hashtag_string}#{record['url'].first}"

        config['last_id_tweeted'] = record['id'].first
      else
        puts "Ignoring ID: #{record['occurred-at']}".red
      end
    end
    write_config_to_file config
  rescue Exception => e
    puts "\033[1mMyBikeLane API call FAILED:\033[22m #{e.message}".red
  else
    puts "Got API response OK!".green
  end
  puts "SLEEPING FOR AN HOUR".cyan
  sleep(3600)
  puts "------ SLEPT FOR AN HOUR. TWEETING NEW POSTS! ------".cyan
end