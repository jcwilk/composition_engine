require 'cgi'

module CompositionEngine
  SESSION_KEY = 'composition_engine'
  PATH_PREFIX = '/engine'

  def self.assign_user_to_session(session,user)
    scope_session(session)['user'] = user
  end

  def self.extract_user_from_session(session)
    scope_session(session)['user']
  end

  def self.scope_session(session)
    session[SESSION_KEY]||= {}
  end

  class User < Hashie::Dash
    property :nickname
    property :uuid
  end

  class Middleware
    attr_accessor :app, :env

    def initialize(_app)
      self.app = _app
    end

    def call(_env)
      self.env = _env
      call_override || app.call(_env)
    end

    def call_override
      case scoped_path
        when false
          LoginHandler.force_login(env) #This returns false and defaults control to the next middleware if they're already logged in
        when '/inspect'
          [200,{'Content-Type' => 'text/plain'},[self.env.keys.map{|k| "#{k.inspect}: #{self.env[k].inspect}"}.join("\n")]]
        when /^#{LoginHandler.resource_path}/
          LoginHandler.handle(env)
        else
          [404,{'ContentType' => 'text/plain'},['Not Found']]
      end
    end

    def scoped_path
      return false if !(env['PATH_INFO'] =~ /^#{PATH_PREFIX}(\/.*)?$/)

      return '/' if $1.nil?
      return $1
    end
  end

  class LoginHandler
    attr_accessor :env

    def self.handle(_env)
      self.new(_env).handle
    end

    def self.force_login(_env)
      inst = self.new(_env)
      if inst.logged_in?
        false
      else
        inst.new_login
      end
    end

    def self.resource_path
      '/login'
    end

    def self.prefixed_path
      PATH_PREFIX+self.resource_path
    end

    def initialize(_env)
      self.env = _env
    end

    def handle
      if request.get?
        new_login
      elsif request.post?
        create_login
      end
    end

    def new_login(message = nil) #TODO: require form key so they can't spam POSTs
      body = <<HTML
<html>
  <body>
    <h1>New User!</h1>
    #{"<em>#{message}</em>" if message}
    <p>Select a handle and click Login</p>
    <form action='#{self.class.prefixed_path}' method='POST'>
      <label for='login_nickname'>Nickname: </label><input type='text' name='login[nickname]' id='login_nickname'/>
      <input type='submit' value='Login' />
    </form>
  </body>
</html>
HTML
      [200,{'ContentType' => 'text/html'},[body]]
    end

    def create_login
      nickname = params['login']['nickname']
      if nickname.nil? || nickname.empty?
        new_login("Nickname must not be blank!")
      else
        user = ::CompositionEngine::User.new(:nickname => nickname, :uuid => UUIDTools::UUID.random_create)
        ::CompositionEngine.assign_user_to_session(session,user)
        [302,{'Location'=>'/'},[]]
      end
    end

    def logged_in?
      ::CompositionEngine.extract_user_from_session(session)
    end

    private

    def scoped_session
      ::CompositionEngine.scope_session(session)
    end

    def session
      request.session
    end

    def params
      request.params
    end

    def request
      @_rack_request||= Rack::Request.new(env)
    end
  end
end