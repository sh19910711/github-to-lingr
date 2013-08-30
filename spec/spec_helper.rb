# coding: utf-8
require 'simplecov'
require 'simplecov-rcov'

require File.join(File.dirname(__FILE__), '..', 'server.rb')
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

