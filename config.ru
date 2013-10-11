# Load Path
$:.unshift(File.expand_path(File.dirname(__FILE__) + "/lib"))

require 'server/app'
run Server::App
