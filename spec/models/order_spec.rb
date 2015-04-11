require 'rails_helper'

describe Order do
  it "should save Order in database" do
    order1 = Order.create(:uuid => "234", :good_id => "453", :agent_id => "45343", :quantity => "2.0")
    expect(Order.all).not_to be_empty
  end
  it "should delete Order by id" do
    order1 = Order.create(:id => "2",:uuid => "234", :good_id => "453", :agent_id => "45343", :quantity => "2.0")
    Order.delete(2)
    expect(Order.all).to be_empty
  end
end