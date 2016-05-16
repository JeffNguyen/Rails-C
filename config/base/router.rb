require_relative 'route'

class Router
  attr_reader :routes

  def initialize
    @routes = []
  end

  def add_route(pattern, method, controller_class, action_name)
    @routes << Route.new(pattern, method, controller_class, action_name)
  end

  def draw(&proc)
    instance_eval(&proc)
  end

  [:get, :post, :put, :delete].each do |http_method|
    define_method(http_method) do |pattern, controller_class, action_name|
      add_route(pattern, http_method, controller_class, action_name)
    end
  end

  def match(req)
    @routes.select { |route| route.matches?(req) }.first
  end

  def resources(name)
    controller = "#{name.to_s.capitalize}Controller".constantize
    get Regexp.new("^/#{name}$"), controller, :index
    get Regexp.new("^/#{name}/new$"), controller, :new
    post Regexp.new("^/#{name}$"), controller, :create
    get Regexp.new("^\/#{name}\/(?<id>\\d+)$"), controller, :show
    get Regexp.new("^\/#{name}\/(?<id>\\d+)\/edit$"), controller, :edit
    put Regexp.new("^\/#{name}\/(?<id>\\d+)$"), controller, :update
    delete Regexp.new("^\/#{name}\/(?<id>\\d+)$"), controller, :destroy
  end

  def run(req, res)
    matched = match(req)
    matched.nil? ? res.status = 404 : matched.run(req,res)
  end
end

class LiteRail
  def self.router
    @router ||= Router.new
  end
end
