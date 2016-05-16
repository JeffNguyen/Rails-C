require './config/router'
require './app/controllers/cats_controller'

server = WEBrick::HTTPServer.new(Port: 3000)
server.mount_proc('/') do |req, res|
  route = LiteRail.router.run(req, res)
end

trap('INT') { server.shutdown }
server.start
