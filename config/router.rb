require_relative 'base/router'
require './app/controllers/cats_controller'
require './app/controllers/humans_controller'
require './app/controllers/houses_controller'

LiteRail.router.draw do
  get Regexp.new("^/$"), HousesController, :index
  resources :cats
  resources :humans
  resources :houses
end
