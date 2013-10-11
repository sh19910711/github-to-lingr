require 'mongoid'

module Server
  module Models
    class User
      include Mongoid::Document

      field :username, type: String
      field :token, type: String
      field :ipaddr, type: String
      field :access_token, type: String
      field :watched, type: Boolean
      field :last_event_id, type: String
    end
  end
end
