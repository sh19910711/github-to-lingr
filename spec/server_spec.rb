# coding: utf-8
require 'spec_helper.rb'

describe 'Server' do
  include Rack::Test::Methods

  before do
    database = Database::get_database
    collection = database.collection('users')
    collection.remove({})
    collection.insert(
      {
        :username => 'sh19910711',
        :token => 'hoge',
        :ipaddr => '::1',
        :access_token => 'fuga',
        :watched => true,
      }
    );
  end

  def app
    @app ||= Sinatra::Application
  end

  class MyHash < Hash
    def id
      ''
    end
    def options
      {}
    end
  end

  def set_login_stub data = {}
    # テスト用のデータベースに事前に格納しておいたデータ
    session = MyHash.new
    session[:token] = data[:token]
    session[:username] = data[:username]
    Rack::Session::Abstract::SessionHash.stub(:new).and_return(session)
  end

  describe 'index' do
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

  describe 'home' do
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
        set_login_stub :token => 'hoge', :username => 'sh19910711'
        post('/logout', {}, {'REMOTE_ADDR' => '::1'})
      end
      it 'HTTP Status' do
        last_response.status.should == 302
      end
      it 'ユーザーのIPアドレスとトークンの初期化が行われているか' do
        database = Database::get_database
        collection = database.collection('users')
        user = collection.find_one({
          :username => 'sh19910711'
        })
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
        database = Database::get_database
        collection = database.collection('users')
        user = collection.find_one({
          :username => 'sh19910711'
        })
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
        database = Database::get_database
        collection = database.collection('users')
        user = collection.find_one({
          :username => 'sh19910711'
        })
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

end
