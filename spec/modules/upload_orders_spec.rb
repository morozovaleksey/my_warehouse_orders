require 'rails_helper'

describe MyWarehouse do
  company = {"moy_sklad_login" => "admin@morozovaleksey", "moy_sklad_password" => "e7c625909866" }
  it "user should be authorized" do
    response = MyWarehouse.moy_sklad_get('CustomerOrder',"list?start=0&count=1000", company)
    expect(response.code).to eql("200")
  end

  it "counter should be bigger 1" do
    response = MyWarehouse.moy_sklad_get('CustomerOrder',"list", company)
    doc = Nokogiri::XML(response.body)
    total = 2000
    MyWarehouse.fill_orders(doc)
    if total > 1000
      counter = 1
      count_response = total/1000
      while count_response >= counter
        response = MyWarehouse.moy_sklad_get('CustomerOrder',"list?start=#{counter*1000}&count=1000", company)
        doc = Nokogiri::XML(response.body)
        MyWarehouse.fill_orders(doc)
        counter+=1
      end
    end
    expect(counter).to be > 1
  end

  it "orders should be updated today or yesterday" do
    time = Date.today
    time_day_ago = time - 1
    response = MyWarehouse.moy_sklad_get('CustomerOrder',"#{URI.encode("list?start=0&count=1000&filter=updated>#{time_day_ago.year}#{time_day_ago.strftime('%m')}#{time_day_ago.strftime('%d')}010000")}",company)
    doc = Nokogiri::XML(response.body)
    total = doc.xpath('//collection/@total').text().to_i
    orders = MyWarehouse.fill_orders(doc)
    counter = 0
    orders.each do |order|
      if order["updated"] == "#{time_day_ago.year}-#{time_day_ago.strftime('%m')}-#{time_day_ago.strftime('%d')}" or
          order["updated"] == "#{time.year}-#{time.strftime('%m')}-#{time.strftime('%d')}"
        counter+=1
      end
    end
    expect(counter).to eql(orders.length)

  end


end