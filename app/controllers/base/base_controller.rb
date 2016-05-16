require 'json'
require 'webrick'
require 'uri'
require 'active_support'
require 'active_support/inflector'
require 'active_support/core_ext'
require 'erb'
require_relative 'params'
require_relative 'session'
require './app/global/global'

class BaseController
  def self.protect_from_forgery
    @@csrf_protection = true
  end

  attr_reader :params, :req, :res

  def initialize(req, res, route_params = {})
    @req, @res = req, res
    @params = Params.new(req, route_params)
  end

  def already_built_response?
    @already_built_response || false
  end

  def csrf_protection
    self.class.class_variable_get(:@@csrf_protection)
  end

  def csrf_violation
    csrf_protection &&
           req.request_method != "GET" &&
           params[:authenticity_token] != session[:form_authenticity_token]
  end

  def flash
    session.flash
  end

  def form_authenticity_token
    session[:form_authenticity_token]
  end

  def invoke_action(name)
    send(name.to_sym)
    render(name) unless @already_built_response
  end

  def render_content(content, content_type)
    session.store_session(@res)
    @res.content_type = content_type
    @res.body = content
    raise "Double Render" if @already_built_response
    @already_built_response = true
  end

  def redirect_to(url)
    session.store_session(@res)
    res.header["location"] = url
    res.status = 302
    raise "Double Render" if @already_built_response
    @already_built_response = true
  end

  def render(template_name)
    controller_name = "#{self.class}".underscore
    f = File.read("./app/views/#{controller_name}/#{template_name}.html.erb")
    content = ERB.new(f).result(binding)
    render_content(content, "text/html")
  end

  def session
    @session ||= Session.new(@req)
  end
end
