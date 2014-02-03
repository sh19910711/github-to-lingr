# coding: utf-8
require 'simplecov'
require 'simplecov-rcov'

# Load Path
$:.unshift(File.expand_path(File.dirname(__FILE__) + "/lib"))
ENV['RACK_ENV'] = 'test'
ENV['MONGODB_URL'] = 'mongodb://localhost:27017/lingrbot-github-to-lingr-test'
ENV['CHECK_REQUEST_TOKEN'] = 'this is test'
ENV['SESSION_SECRET'] = 'this is test'

# MongoDB
require 'mongoid'
Mongoid.load!("./mongoid.yml", ENV['RACK_ENV'].to_sym)

require 'webmock'
WebMock.disable_net_connect!

=begin
require 'fakefs/safe'
require 'fakefs/spec_helpers'
RSpec.configure do |config|
  config.include FakeFS::SpecHelpers
end
=end

require 'rubygems'
require 'spork'

Spork.prefork do
  require 'sinatra'
  require 'rack/test'
  require 'rack/csrf'
  require 'rspec'

  def session
    last_request.env['rack.session']
  end

  RSpec.configure do |config|
    config.include Rack::Test::Methods

    config.treat_symbols_as_metadata_keys_with_true_values = true
    config.run_all_when_everything_filtered = true
    config.filter_run :focus

    # Run specs in random order to surface order dependencies. If you find an
    # order dependency and want to debug it, you can fix the order by providing
    # the seed, which is printed after each run.
    #     --seed 1234
    config.order = 'random'
  end

  SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
end

Spork.prefork do
  unless ENV['DRB']
    require 'simplecov'
  end
end

Spork.each_run do
  # This code will be run each time you run your specs.
  if ENV['DRB']
    require 'simplecov'
  end
end

