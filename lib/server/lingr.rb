require 'digest/sha1'
require 'uri'
require 'net/http'
require 'json'

# 環境変数: LINGR_ROOM_ID, LINGR_BOT_ID, LINGR_BOT_SECRET
class Lingr

  def initialize( room_id, bot_id, bot_secret )
    @room_id = room_id
    @bot_id = bot_id
    @bot_secret = bot_secret
    @bot_verifier = Digest::SHA1.hexdigest(@bot_id + @bot_secret)
    @api_url = 'http://lingr.com/api/room/say'
    @api_uri = URI.parse(@api_url)
  end

  def say(message)
    request = Net::HTTP::Post.new(@api_uri.request_uri, initheader = {
      'Content-Type' => 'application/json'
    })
    request.body = {
      room: @room_id,
      bot: @bot_id,
      text: message,
      bot_verifier: @bot_verifier,
    }.to_json

    http = Net::HTTP.new(@api_uri.host, @api_uri.port)
    http.start {|http|
      response = http.request(request)
    }
  end
end

