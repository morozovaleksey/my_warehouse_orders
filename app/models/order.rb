class Order < ActiveRecord::Base
  validates :uuid, uniqueness: true, :allow_nil => false
  validates :sum,  presence: true
  validates :base_price,  presence: true
  validates :good_id,  presence: true
  validates :agent_id,  presence: true
  validates :quantity,  presence: true
end
