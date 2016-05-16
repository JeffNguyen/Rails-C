require './app/models/base/active_record.rb'
require_relative 'human'
require_relative 'cat'

class House < ActiveRecord::Base
  validates :address, presence: true

  has_many :inhabitants, class_name: :Human
  has_many :cats, through: :inhabitants

  self.finalize!
end
