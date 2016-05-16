require './app/models/base/active_record.rb'
require_relative 'house'
require_relative 'human'


class Cat < ActiveRecord::Base
  validates :name, :owner, presence: true
  validates :name, uniqueness: true

  belongs_to :owner, class_name: :Human, foreign_key: :owner_id
  belongs_to :house, through: :owner

  self.finalize!
end
