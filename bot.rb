#!/usr/bin/env ruby
require 'yaml'
# require 'twitter4r'

secrets = YAML.load_file('secrets.yml')

Twitter.configure do |config|
  config.oauth_consumer_token = secrets['oauth']['consumer_token']
  config.oauth_consumer_secret = secrets['oauth']['consumer_token']
end