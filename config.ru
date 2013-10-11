# Load Path
$:.unshift(File.expand_path(File.dirname(__FILE__) + "/lib"))

# MongoDB
require 'mongoid'
Mongoid.load!(File.expand_path(File.dirname(__FILE__) + "/mongoid.yml"), ENV['RACK_ENV'].to_sym)

require 'server/app'
run Server::App
