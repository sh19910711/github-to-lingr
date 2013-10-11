require 'mongoid'

module Server
  module Models
    class Cache
      include Mongoid::Document
      field :commit_id, type: String
    end
  end
end
