require_relative 'application_controller'
require './app/models/cat'

class CatsController < ApplicationController
  def create
    @cat = Cat.new(cat_params)
    if @cat.save
      redirect_to "/cats/#{@cat.id}"
    else
      flash[:errors] = @cat.errors.full_messages
      render :new
    end
  end

  def destroy
    @cat = Cat.find(params[:id])
    @cat.destroy
    redirect_to '/cats'
  end

  def edit
    @cat = Cat.find(params[:id])
  end

  def index
    @cats = Cat.all
  end

  def new
    @cat = Cat.new
  end

  def show
    @cat = Cat.find(params[:id])
  end

  def update
    @cat = Cat.find(params[:id])

    if @cat.update(cat_params)
      redirect_to "/cats/#{@cat.id}"
    else
      flash[:errors] = @cat.errors.full_messages
      render :edit
    end
  end

  private

  def cat_params
    params.require(:cat).permit(:name, :owner_id)
  end
end
