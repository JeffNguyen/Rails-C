require './app/models/base/active_record.rb'
require_relative 'cat'
require_relative 'house'

class Human < ActiveRecord::Base
  validates :fname, :lname, :house, presence: true

  has_many :cats, foreign_key: :owner_id
  belongs_to :house

  self.finalize!
end
