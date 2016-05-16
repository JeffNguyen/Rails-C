require_relative 'application_controller'
require './app/models/house'

class HousesController < ApplicationController
  def create
    @house = House.new(house_params)

    if @house.save
      redirect_to '/houses'
    else
      flash[:errors] = @house.errors.full_messages
      render :new
    end
  end

  def destroy
    @house = House.find(params[:id])
    @house.destroy
    redirect_to '/houses'
  end

  def edit
    @house = House.find(params[:id])
  end

  def index
    @houses = House.includes(:inhabitants).all
  end

  def new
    @house = House.new
  end

  def update
    @house = House.find(params[:id])

    if @house.update(house_params)
      redirect_to "/houses"
    else
      flash[:errors] = @house.errors.full_messages
      render :edit
    end
  end

  private

  def house_params
    params.require(:house).permit(:address)
  end
end
