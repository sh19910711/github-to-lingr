# -*- coding:utf-8 -*-
require 'sinatra'
require 'net/https'
require 'json'
require 'octokit'
require 'securerandom'
require 'uri'
require './sources/database.rb'
require './sources/lingr.rb'

SESSION_SECRET = ENV['SESSION_SECRET']
GITHUB_CLIENT_ID = ENV['GITHUB_CLIENT_ID']
GITHUB_CLIENT_SECRET = ENV['GITHUB_CLIENT_SECRET']
CHECK_REQUEST_TOKEN = ENV['CHECK_REQUEST_TOKEN']

def is_logged_in?
    return false if ! session[:token] || session[:token].empty?
    database = Database::get_database
    collection = database.collection('users')
    userinfo = collection.find_one(:username => session[:username])
    # ログインチェック
    if userinfo.nil? || ( userinfo['ipaddr'] == '' || request.ip != userinfo['ipaddr'] ) || ( userinfo['token'] == '' || session[:token] != userinfo['token'] )
        session.clear
        return false
    end
    return true
end

def logout
    if is_logged_in?
        database = Database::get_database
        collection = database.collection('users')
        collection.update({
            'username' => session[:username]
        }, {'$set' => {
            'token' => '',
            'ipaddr' => ''
        }})
    end
    session.clear
end

use Rack::Session::Cookie, :secret => SESSION_SECRET

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
        database = Database::get_database
        collection = database.collection('users')
        user = collection.find_one(:username => session[:username])
        watched_str = user['watched'] ? '<strong>有効</strong>' : '無効'
        @body = '<ul><li>監視状態: ' + watched_str + '</li><li><a href="/register">監視設定を有効にする</a></li><li><a href="/unregister">監視設定を解除する</a></li><li><a href="/logout">ログアウト</a></li></ul>'
    else
        @body = '<a href="/login">ログイン</a>'
    end
    haml :home
end

# ログイン
get '/login' do
    scheme = ENV['https'] == 'on' ? 'https' : 'http'
    query = {
        :client_id => GITHUB_CLIENT_ID,
        :redirect_uri => "#{scheme}://#{env['HTTP_HOST']}/auth-callback",
        :scope => ''
    }
    
    query_str = query.map{|k, v|
        "#{k}=#{URI.encode v}"
    }.join('&')

    redirect "https://github.com/login/oauth/authorize?#{query_str}"
end

# OAuth認証時の戻り先
get '/auth-callback' do
    ipaddr = request.ip
    code = params['code']
    redirect '/auth-result'if code.nil? || code.to_s.empty?

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
        client = Octokit::Client.new(:oauth_token => access_token)
        username = client.user.login
        token = SecureRandom.hex(253)

        session[:username] = username
        session[:token] = token

        # セッションを記録
        database = Database::get_database
        collection = database.collection('users')
        user = collection.find_one(:username => username)
        if user
            collection.update({
                'username' => username
            }, {'$set' => {
                'token' => token,
                'ipaddr' => ipaddr,
                'access_token' => access_token
            }})
        else
            last_event_id = client.user_public_events(username)[0]['id']
            # 新規ユーザー
            collection.insert({
                'username' => username,
                'token' => token,
                'ipaddr' => ipaddr,
                'access_token' => access_token,
                'watched' => true,
                'last_event_id' => last_event_id
            })
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
get '/logout' do
    logout
    redirect '/home'
end

# 監視登録
get '/register' do
    if is_logged_in?
        database = Database::get_database
        collection = database.collection('users')
        user = collection.find_one(:username => session[:username])
        collection.update({
            'username' => session[:username]
        }, {'$set' => {
            'watched' => true,
        }})
        @body = '監視設定を有効にしました。<a href="/home">ホーム</a>へ'
        haml :register
    else
        redirect '/home'
    end
end

# 監視解除
get '/unregister' do
    if is_logged_in?
        database = Database::get_database
        collection = database.collection('users')
        user = collection.find_one(:username => session[:username])
        collection.update({
            'username' => session[:username]
        }, {'$set' => {
            'watched' => false,
        }})
        @body = '監視設定を解除しました。<a href="/home">ホーム</a>へ'
        haml :register
    else
        redirect '/home'
    end
end

def check_github_events user
    if user['access_token'].empty? || ! user['watched']
        return
    end

    begin
        client = Octokit::Client.new(:oauth_token => user['access_token'])
        events = client.user_public_events(user['username'])
    rescue
        database = Database::get_database
        collection = database.collection('users')
        collection.update({
            username: user['username']
        }, {'$set' => {
            'access_token' => '',
            'ipaddr' => '',
            'token' => ''
        }})
    end

    all_commits = []
    table = Hash.new([])
    last_event_id = user['last_event_id']
    events.each {|event|
        if event['type'] == 'PushEvent'
            actor = event['actor']
            repo = event['repo']
            id = event['id'].to_i
            commits = event['payload']['commits']

            if id > user['last_event_id'].to_i && commits.length > 0
                commits.each {|commit|
                    if ! table.has_key?(commit['sha'])
                        table[commit['sha']] = true
                        all_commits.push({
                            'actor' => actor,
                            'repo' => repo,
                            'commit' => commit
                        })
                    end
    }
            end
            last_event_id = [last_event_id.to_i, id].max
        end
    }

    if all_commits.length > 0
        Lingr::say "### " + user['username'] + " が " + all_commits.length.to_s + " 個コミット ###\n"
        all_commits.each {|commit_info|
            url = 'https://github.com/' + commit_info['repo']['name'] + '/commit/' + commit_info['commit']['sha']
            commit_message = "[" + commit_info['repo']['name'] + "] " + commit_info['commit']['message'] + "\n" + url + "\n"
            Lingr::say commit_message
        }
        Lingr::say "- - - - -\n"
    end

    database = Database::get_database
    collection = database.collection('users')
    collection.update({
        username: user['username']
    }, {'$set' => {
        'last_event_id' => last_event_id
    }})

    ""
end

# 更新を確認する
user_index = 0
post '/check' do
    halt 403 if CHECK_REQUEST_TOKEN != params[:token]

    database = Database::get_database
    collection = database.collection('users')
    users = collection.find({
        'watched' => true
    }).to_a
    return "" if users.empty?
    user_index %= users.length
    check_github_events(users[user_index])
    user_index = ( user_index + 1 ) % users.length
    ""
end

