require 'ncc'
require 'rack/logger'

NCC.configure do |c|
    c.config_path = '/etc/ncc/'
end

require 'ncc-api'

configure :development do
   set :logging, Logger::DEBUG
end

run Sinatra::Application
