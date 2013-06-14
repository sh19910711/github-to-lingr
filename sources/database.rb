require 'mongo'
require 'uri'
require 'pp'

module Database
    include Mongo

    MONGOHQ_URL = ENV['MONGOHQ_URL']
    MONGOHQ_URI = URI.parse(MONGOHQ_URL)

    def self.get_database
        client = MongoClient.new(MONGOHQ_URI.host, MONGOHQ_URI.port)
        database = client.db(MONGOHQ_URI.path[1..-1])
        database.authenticate(MONGOHQ_URI.user, MONGOHQ_URI.password)
        database
    end
end

