require_relative 'application_controller'
require './app/models/human'

class HumansController < ApplicationController
  def create
    @human = Human.new(human_params)

    if @human.save
      redirect_to "/humans/#{@human.id}"
    else
      flash[:errors] = @human.errors.full_messages
      render :new
    end
  end

  def destroy
    @human = Human.find(params[:id])
    @human.destroy
    redirect_to '/humans'
  end

  def edit
    @human = Human.find(params[:id])
  end

  def index
    @humans = Human.includes(:cats).all
  end

  def new
    @human = Human.new
  end

  def show
    @human = Human.find(params[:id])
  end

  def update
    @human = Human.find(params[:id])

    if @human.update(human_params)
      redirect_to "/humans/#{@human.id}"
    else
      flash[:errors] = @human.errors.full_messages
      render :edit
    end
  end

  private

  def human_params
    params.require(:human).permit(:fname, :lname, :house_id)
  end
end
