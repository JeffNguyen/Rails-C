require './app/controllers/base/base_controller'

class ApplicationController < BaseController
  protect_from_forgery
end
