# coding:utf-8
require 'sinatra/base'
require 'rack/csrf'
require 'net/https'
require 'json'
require 'octokit'
require 'securerandom'
require 'uri'
require 'cgi'
require 'time'
require 'haml'

require 'server/models/user'
require 'server/models/cache'
require 'server/lingr'

module Server
  SESSION_SECRET       = ENV['SESSION_SECRET']
  GITHUB_CLIENT_ID     = ENV['GITHUB_CLIENT_ID']
  GITHUB_CLIENT_SECRET = ENV['GITHUB_CLIENT_SECRET']
  CHECK_REQUEST_TOKEN  = ENV['CHECK_REQUEST_TOKEN']
  ROOM_ID              = ENV['LINGR_ROOM_ID']
  BOT_ID               = ENV['LINGR_BOT_ID']
  BOT_SECRET           = ENV['LINGR_BOT_SECRET']

  class App < Sinatra::Base
    def is_logged_in?
      return false if ! session[:token] || session[:token].empty?
      userinfo = Models::User.where(:username => session[:username]).cache.first
      # ログインチェック
      if userinfo.nil? || ( userinfo['ipaddr'] == '' || request.ip != userinfo['ipaddr'] ) || ( userinfo['token'] == '' || session[:token] != userinfo['token'] )
        session.clear
        return false
      end
      return true
    end

    def uri_encode(s)
      CGI::escape(s)
    end

    def logout
      if is_logged_in?
        Models::User
        .where(
          :username => session[:username],
        )
        .update(
          :token => '',
          :ipaddr => '',
        )
      end
      session.clear
    end

    use Rack::Session::Cookie, :secret => SESSION_SECRET

    configure :production, :development do
      use Rack::Csrf, :field => 'csrf_field', :skip => ['POST:/check']
    end

    # Lingrからのアクセス用
    get '/lingr' do
      redirect '/home'
    end

    # Lingr hook用
    post '/lingr' do
      request.body.rewind
      request.body.read
      ''
    end

    # リダイレクトする
    get '/' do
      redirect '/home'
    end

    # ホーム画面
    get '/home' do
      if is_logged_in?
        users = Server::Models::User.where(:username => session[:username]).cache
        user = users.first
        @watched_str = user['watched'] ? '<strong>有効</strong>' : '無効'
        haml :homemenu
      else
        haml :home
      end
    end

    # ログイン
    post '/login' do
      scheme = ENV['https'] == 'on' ? 'https' : 'http'
      query = {
        :client_id => GITHUB_CLIENT_ID,
        :redirect_uri => "#{scheme}://#{env['HTTP_HOST']}/auth-callback",
        :scope => ''
      }

      query_str = query.map{|k, v|
        "#{k}=#{uri_encode(v)}"
      }.join('&')

      redirect "https://github.com/login/oauth/authorize?#{query_str}"
    end

    # OAuth認証時の戻り先
    get '/auth-callback' do
      ipaddr = request.ip
      code = params['code']
      redirect '/auth-result' if code.nil? || code.to_s.empty?

      url = 'https://github.com/login/oauth/access_token'
      uri = URI.parse(url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.start {|http|
        begin
          request = Net::HTTP::Post.new('/login/oauth/access_token', initheader = {
            'Content-Type' => 'application/json',
            'Accept' => 'application/json'
          })
          request.body = {
            :client_id => GITHUB_CLIENT_ID,
            :client_secret => GITHUB_CLIENT_SECRET,
            :code => code
          }.to_json
          response = http.request(request)
        end

        # アクセストークンの取得
        result = JSON.parse(response.body)
        access_token = result['access_token']
        client = Octokit::Client.new(:access_token => access_token)
        username = client.user.login
        token = SecureRandom.hex(253)

        session[:username] = username
        session[:token] = token
        p session

        # セッションを記録
        user = Server::Models::User.where(:username => username)
        if user.count > 0
          user.update(
            :token        => token,
            :ipaddr       => ipaddr,
            :access_token => access_token,
          )
        else
          last_event_id = client.user_public_events(username)[0]['id']
          # 新規ユーザー
          user.create(
            :username      => username,
            :token         => token,
            :ipaddr        => ipaddr,
            :access_token  => access_token,
            :watched       => true,
            :last_event_id => last_event_id,
          )
        end
      }

      redirect '/auth-result'
    end

    # ログインできたかどうかを判定する
    get '/auth-result' do
      res = 'ログイン'
      if is_logged_in?
        res += '成功'
      else
        res += '失敗'
      end
      res += ', <a href="/home">ホーム</a>へ'
      @body = res
      haml :authresult
    end

    # ログアウト
    post '/logout' do
      logout
      redirect '/home'
    end

    # 監視登録
    post '/register' do
      if is_logged_in?
        user = Server::Models::User.where(:username => session[:username])
        user.update({
          :watched => true,
        })
        @body = '監視設定を有効にしました。<a href="/home">ホーム</a>へ'
        haml :register
      else
        redirect '/home'
      end
    end

    # 監視解除
    post '/unregister' do
      if is_logged_in?
        user = Server::Models::User.where(:username => session[:username])
        user.update({
          :watched => false,
        })
        @body = '監視設定を解除しました。<a href="/home">ホーム</a>へ'
        haml :register
      else
        redirect '/home'
      end
    end

    def get_new_commits_from_events(events, user_last_event_id)
      all_commits = []
      table = Hash.new([])
      last_event_id = user_last_event_id
      events.each {|event|
        if event['type'] == 'PushEvent'
          actor   = event['actor']
          repo    = event['repo']
          id      = event['id'].to_i
          commits = event['payload']['commits']

          if id > user_last_event_id && commits.length > 0
            commits.reverse.each {|commit|
              cache = Server::Models::Cache.where(:commit_id => commit['sha'])
              cache.cache
              if ! cache.exists? && ! table.has_key?(commit['sha'])
                cache.create
                table[commit['sha']] = true
                all_commits.push({
                  'actor'  => actor,
                  'repo'   => repo,
                  'commit' => commit
                })
              end
            }
          end
          last_event_id = [last_event_id, id.to_i].max
        end
      }
      return [all_commits, last_event_id]
    end

    def get_last_event_id(events)
      last_event_id = 0
      events.each {|event|
        if event['type'] == 'PushEvent'
          id = event['id'].to_i
          last_event_id = [last_event_id, id.to_i].max
        end
      }
      return last_event_id
    end

    def check_github_events user
      if user['access_token'].empty? || ! user['watched']
        return
      end

      begin
        client = Octokit::Client.new(:access_token => user['access_token'])
        events = client.user_public_events(user['username'])
      rescue => error
        # 不正なアクセストークンを削除する
        if /GET .*?: 401:/.match(error.to_s)
          Server::Models::User
          .where({
            username: user['username'],
          })
          .update({
            :access_token => '',
            :ipaddr => '',
            :token => '',
          })
        end
        return
      end

      if user['last_event_id'].nil?
        last_event_id = get_last_event_id(events)
        Server::Models::User
        .where({
          username: user['username'],
        })
        .update({
          :last_event_id => last_event_id
        })
        return ''
      end

      (all_commits, last_event_id) = get_new_commits_from_events(events, user['last_event_id'].to_i)

      lingr = Lingr.new(ROOM_ID, BOT_ID, BOT_SECRET)
      if all_commits.length > 0
        lingr.say "### " + user['username'] + " が " + all_commits.length.to_s + " 個コミット ###\n"
        all_commits.each {|commit_info|
          url = 'https://github.com/' + commit_info['repo']['name'] + '/commit/' + commit_info['commit']['sha']
          commit_message = "[" + commit_info['repo']['name'] + "] " + commit_info['commit']['message'] + "\n" + url + "\n"
          lingr.say commit_message
        }
        lingr.say "- - - - -\n"
      end

      Server::Models::User.where({
        :username => user['username'],
      }).update({
          'last_event_id' => last_event_id,
        })

      return ''
    end

    # 更新を確認する
    user_index = 0
    post '/check' do
      halt 403 if CHECK_REQUEST_TOKEN.nil? || CHECK_REQUEST_TOKEN != params[:token]

      users = Server::Models::User.where({
        :watched => true
      }).cache.to_a
      return "empty" if users.empty?
      user_index %= users.length
      check_github_events(users[user_index])
      user_index = ( user_index + 1 ) % users.length
      "ok"
    end

    configure :development do
      get '/check' do
        users = Server::Models::User.where({
          :watched => true
        }).to_a
        return "" if users.empty?
        user_index %= users.length
        check_github_events(users[user_index])
        user_index = ( user_index + 1 ) % users.length
        ""
      end
    end

    configure :test do
      helpers do
        def csrf_tag
          ''
        end
        def csrf_token
          ''
        end
      end
    end

    configure :production, :development do
      helpers do
        def csrf_token
          Rack::Csrf.csrf_token(env)
        end
        def csrf_tag
          Rack::Csrf.csrf_tag(env)
        end
      end
    end
  end
end
