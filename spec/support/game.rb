class Game < Sinatra::Base
  use Rack::Session::Pool
  use CompositionEngine::Middleware

  def current_user
    CompositionEngine.extract_user_from_session(session)
  end

  get '/' do
    "Welcome #{current_user.nickname}"
  end
end