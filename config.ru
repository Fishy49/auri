require './app'

# Enable method override for DELETE requests
use Rack::MethodOverride

run Sinatra::Application
