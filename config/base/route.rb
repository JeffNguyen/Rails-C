class Route
  attr_reader :pattern, :http_method, :controller_class, :action_name

  def initialize(pattern, http_method, controller_class, action_name)
    @pattern = pattern
    @http_method = http_method
    @controller_class = controller_class
    @action_name = action_name
  end

  def csrf_violation(controller)
    csrf_protection &&
           req.request_method != "GET" &&
           params[:authenticity_token] != session[:form_authenticity_token]
  end

  def matches?(req)
    if req.body && req.body.match(/\_method\=DELETE/)
      return false unless http_method == :delete
    elsif req.body && req.body.match(/\_method\=PATCH/)
      return false unless http_method == :patch || http_method == :put
    else
      return false unless req.request_method.downcase.to_sym == http_method
    end

    !!pattern.match(req.path)
  end

  def run(req, res)
    controller = controller_class.new(req, res, extract_route_params(req))

    if controller.csrf_violation
      controller.res.status = 422
    else
      controller.invoke_action(action_name)
    end
  end

  private

  def extract_route_params(req)
    route_params = {}
    match_data = pattern.match(req.path)
    match_data.names.each do |name|
      route_params[name.to_sym] = match_data[name]
    end
    route_params
  end
end
