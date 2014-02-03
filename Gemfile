source 'https://rubygems.org'

ruby '2.1.0'

group :production, :development do
  gem 'sinatra'
  gem 'sinatra-contrib'
  gem 'haml'
  gem 'octokit'
  gem 'mongoid', '~> 3.0.0'
  gem 'mongo_ext'
  gem 'bson_ext'
  gem 'rack_csrf'
end

group :development do
  gem 'rake'
  gem 'shotgun'
  gem 'byebug'
  gem 'pry'
end

group :test do
  gem 'rspec'
  gem 'rack-test', require: 'rack/test'
  gem 'spork'
  gem 'simplecov', require: false
  gem 'simplecov-rcov'
  gem 'ci_reporter'
  gem 'webmock'
  gem 'fakefs'
end

