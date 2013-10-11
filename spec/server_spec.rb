# coding: utf-8
require 'spec_helper.rb'
require 'server/models/user'
require 'server/models/cache'
require 'server/app'

require 'webmock/rspec'
WebMock.allow_net_connect!

describe 'Server' do
  include Rack::Test::Methods

  def reset_user
    Server::Models::User
    .find_or_create_by(
      :username => 'sh19910711',
    )

    Server::Models::User
    .where(
      :username => 'sh19910711',
    )
    .update({
      :username      => 'sh19910711',
      :token         => 'hoge',
      :ipaddr        => '::1',
      :access_token  => '1acc8876597a612db3b27748ae03ef75eb6ba093',
      :watched       => true,
      :last_event_id => '1789831268',
    })
  end

  def reset_cache
    Server::Models::Cache.all.delete
  end

  # テスト用のデータベースを作成する
  before do
    reset_user
    reset_cache
  end

  # GitHub API: public eventsのモック
  before do
    response_body = File.read(File.dirname(__FILE__) + '/mock/github_api_sh19910711_public_event_result.json')
    stub_request(:get, 'https://api.github.com/users/sh19910711/events/public').to_return(
      {
        :status => 200,
        :headers => {
          'Content-Length' => response_body.length,
          'Content-Type' => 'application/json',
        },
        :body => response_body,
      },
    )
  end

  # サーバーアプリ
  def app
    Server::App
  end

  # セッションで利用するハッシュのモック
  class MyHash < Hash
    def id
      ''
    end
    def options
      {}
    end
  end

  # Lingrクラスのモック
  class FakeLingr
    def initialize
      # p "hello"
    end
    def say(message)
      # p "fake say: #{message}"
    end
  end

  def set_login_stub(data = {})
    # テスト用のデータベースに事前に格納しておいたデータ
    session = MyHash.new
    session[:token] = data[:token]
    session[:username] = data[:username]
    Rack::Session::Abstract::SessionHash.stub(:new).and_return(session)
  end

  def where_user_first
    ret = Server::Models::User.where(
      :username => 'sh19910711'
    )
    ret.first
  end

  describe 'GET /' do
    context 'HTTPステータスの確認' do
      before do 
        get '/'
      end
      subject do
        last_response.status
      end
      it '302を返すべき' do
        should == 302
      end
    end
  end

  describe 'GET /home' do
    context 'HTTPステータスの確認' do
      before do
        get '/home'
      end
      subject do
        last_response.status
      end
      it '200' do
        should == 200
      end
    end

    context 'Viewのチェック' do
      before do
        get '/home'
      end
      subject do
        last_response.body.include?('GitHub To Lingrについて')
      end
      it '説明文があるかどうか' do
        should == true
      end
    end

    context 'ログイン前' do
      before do
        get '/home'
      end
      it 'logout/ログアウトという文字列を含まない' do
        last_response.body.include?('logout').should == false 
        last_response.body.include?('ログアウト').should == false
      end
    end

    context '不正なトークン.1' do
      before do
        # テスト用のデータベースに事前に格納しておいたデータ
        set_login_stub :token => 'hogea', :username => 'sh19910711'
        get('/home', {}, {'REMOTE_ADDR' => '::1'})
      end
      it 'logout/ログアウトという文字列を含まない' do
        last_response.body.include?('logout').should == false 
        last_response.body.include?('ログアウト').should == false
      end
    end

    context '不正なトークン.2' do
      before do
        # テスト用のデータベースに事前に格納しておいたデータ
        set_login_stub :token => 'ahoge', :username => 'sh19910711'
        get('/home', {}, {'REMOTE_ADDR' => '::1'})
      end
      it 'logout/ログアウトという文字列を含まない' do
        last_response.body.include?('logout').should == false 
        last_response.body.include?('ログアウト').should == false
      end
    end

    context '不正なトークン.3' do
      before do
        # テスト用のデータベースに事前に格納しておいたデータ
        set_login_stub :token => '', :username => 'sh19910711'
        get('/home', {}, {'REMOTE_ADDR' => '::1'})
      end
      it 'logout/ログアウトという文字列を含まない' do
        last_response.body.include?('logout').should == false 
        last_response.body.include?('ログアウト').should == false
      end
    end

    context 'ログイン後' do
      before do
        set_login_stub :token => 'hoge', :username => 'sh19910711'
        get('/home', {}, {'REMOTE_ADDR' => '::1'})
      end
      it 'logout/ログアウトという文字列を含む' do
        last_response.body.include?('logout').should == true
        last_response.body.include?('ログアウト').should == true
      end
    end
  end

  describe '/logout' do
    context 'ログアウト' do
      before do
        set_login_stub(:token => 'hoge', :username => 'sh19910711')
        post('/logout', {}, {'REMOTE_ADDR' => '::1'})
      end
      it 'HTTP Status' do
        last_response.status.should == 302
      end
      it 'ユーザーのIPアドレスとトークンの初期化が行われているか' do
        user = where_user_first
        user['ipaddr'].should == ''
        user['token'].should == ''
      end
    end
  end

  describe '/register' do
    context '監視設定有効化' do
      before do
        set_login_stub :token => 'hoge', :username => 'sh19910711'
        post('/register', {}, {'REMOTE_ADDR' => '::1'})
      end
      it '監視設定が有効化されているか' do
        user = where_user_first
        user['watched'].should == true
      end
    end
    context 'GETリクエストでアクセスできないことを確認' do
      before do
        set_login_stub :token => 'hoge', :username => 'sh19910711'
        get('/register', {}, {'REMOTE_ADDR' => '::1'})
      end
      it '404であるべき' do
        last_response.status.should == 404
      end
    end
    context '非ログイン時はリダイレクト' do
      before do
        post('/register', {}, {'REMOTE_ADDR' => '::1'})
      end
      it '/homeへリダイレクト' do
        last_response.status.should == 302
        last_response.original_headers['Location'].include?('/home').should == true
      end
    end
  end

  describe '/unregister' do
    context '監視設定無効化' do
      before do
        set_login_stub :token => 'hoge', :username => 'sh19910711'
        post('/unregister', {}, {'REMOTE_ADDR' => '::1'})
      end
      it '監視設定が無効化されているか' do
        user = where_user_first
        user['watched'].should == false
      end
    end
    context 'GETリクエストでアクセスできないことを確認' do
      before do
        set_login_stub :token => 'hoge', :username => 'sh19910711'
        get('/unregister', {}, {'REMOTE_ADDR' => '::1'})
      end
      it '404であるべき' do
        last_response.status.should == 404
      end
    end
    context '非ログイン時はリダイレクト' do
      before do
        post('/unregister', {}, {'REMOTE_ADDR' => '::1'})
      end
      it '/homeへリダイレクト' do
        last_response.status.should == 302
        last_response.original_headers['Location'].include?('/home').should == true
      end
    end
  end

  describe '/check' do
    context 'GETリクエストなどでアクセスできないことを確認' do
      before do
        get('/check', {}, {})
      end
      it '404であるべき' do
        last_response.status.should == 404
      end
    end
    context '実行してみる' do
      before do
        Server::Lingr.stub(:new).and_return(FakeLingr.new())
        post('/check', {'token' => ENV['CHECK_REQUEST_TOKEN']}, {})
      end
      it '200であるべき' do
        last_response.status.should == 200
      end
    end
    context '実行回数の計測' do
      before do
        # Lingrクラスのモック
        class FakeLingr
          def initialize
            @@cnt = 0
          end
          def say(message)
            @@cnt += 1 if /^\[/.match message
          end
          def self.get_cnt
            @@cnt
          end
        end
      end
      before do
        Server::Lingr.stub(:new).and_return(FakeLingr.new())
        post('/check', {'token' => ENV['CHECK_REQUEST_TOKEN']}, {})
      end
      it '200' do
        last_response.status.should == 200
        FakeLingr.get_cnt.should eq 27
      end
    end
    context '二度目は無いということ' do
      before do
        # Lingrクラスのモック
        class FakeLingr
          def initialize
            @@cnt = 0
          end
          def say(message)
            @@cnt += 1 if /^\[/.match message
          end
          def self.get_cnt
            @@cnt
          end
        end
      end
      before do
        Server::Lingr.stub(:new).and_return(FakeLingr.new())
        post('/check', {'token' => ENV['CHECK_REQUEST_TOKEN']}, {})
        Server::Lingr.stub(:new).and_return(FakeLingr.new())
        reset_user
        post('/check', {'token' => ENV['CHECK_REQUEST_TOKEN']}, {})
      end
      it '200' do
        last_response.status.should == 200
        FakeLingr.get_cnt.should eq 0
      end
    end
  end

end
