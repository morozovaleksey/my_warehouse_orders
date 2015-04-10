class Order < ActiveRecord::Base
  validates :uuid, uniqueness: true
end
