require 'digest/sha1'
require 'uri'
require 'net/http'
require 'json'

# 環境変数: LINGR_ROOM_ID, LINGR_BOT_ID, LINGR_BOT_SECRET
module Lingr
    ROOM_ID = ENV['LINGR_ROOM_ID']
    BOT_ID = ENV['LINGR_BOT_ID']
    BOT_SECRET = ENV['LINGR_BOT_SECRET']
    BOT_VERIFIER = Digest::SHA1.hexdigest(BOT_ID + BOT_SECRET)
    API_URL = 'http://lingr.com/api/room/say'
    API_URI = URI.parse(API_URL)

    def self.say(message)
        request = Net::HTTP::Post.new(API_URI.request_uri, initheader = {
            'Content-Type' => 'application/json'
        })
        request.body = {
            room: ROOM_ID,
            bot: BOT_ID,
            text: message,
            bot_verifier: BOT_VERIFIER
        }.to_json

        http = Net::HTTP.new(API_URI.host, API_URI.port)
        http.start {|http|
            response = http.request(request)
        }
    end
end

