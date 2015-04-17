require 'builder'
require 'nokogiri'
require 'net/http'

module MyWarehouse
  @@company = {"moy_sklad_login" => "admin@morozovaleksey", "moy_sklad_password" => "e7c62590986" }

  def self.upload_orders
    response = self.moy_sklad_get('CustomerOrder',"list?start=0&count=1000", @@company)
    doc = Nokogiri::XML(response.body)
    total = doc.xpath('//collection/@total').text().to_i
    self.fill_orders(doc)
    if total > 1000
      counter = 1
      count_response = total/1000
      while count_response >= counter
        response = self.moy_sklad_get('CustomerOrder',"list?start=#{counter*1000}&count=1000", @@company)
        doc = Nokogiri::XML(response.body)
        self.fill_orders(doc)
        counter+=1
      end
    end

  end

  def self.upload_latest_orders
    time = Date.today
    time_day_ago = time - 1
    response = self.moy_sklad_get('CustomerOrder',"#{URI.encode("list?start=0&count=1000&filter=updated>#{time_day_ago.year}#{time_day_ago.strftime('%m')}#{time_day_ago.strftime('%d')}010000")}", @@company)
    doc = Nokogiri::XML(response.body)
    total = doc.xpath('//collection/@total').text().to_i
    self.fill_orders(doc)
    if total > 1000
      counter = 1
      count_response = total/1000
      while count_response >= counter
        response = self.moy_sklad_get('CustomerOrder',"#{URI.encode("list?start=#{counter*1000}&count=1000&filter=updated>#{time_day_ago.year}#{time_day_ago.strftime('%m')}#{time_day_ago.strftime('%d')}010000")}", @company)
        doc = Nokogiri::XML(response.body)
        self.fill_orders(doc)
        counter+=1
      end
    end
  end

  def self.fill_orders doc
    orders_my_warehouse = doc.xpath('//collection/customerOrder').map do |i|
      {'uuid' => i.xpath('uuid').text(),'groupUuid' => i.xpath('groupUuid').text(),'updated' => i.xpath('@updated').text().split('T')[0],
       'customerOrderPosition' => {'quantity' => i.xpath('customerOrderPosition/@quantity').text(),
                                   'goodUuid' => i.xpath('customerOrderPosition/@goodUuid').text(),
                                   'basePrice' =>(i.xpath('customerOrderPosition/basePrice/@sum').text().to_d)/100,
                                   'sum' =>(i.xpath('sum/@sum').text().to_d)/100,
                                   'sourceAgentUuid' => i.xpath('@sourceAgentUuid').text() },
      }

    end
    unless orders_my_warehouse.blank?
      orders_my_warehouse.each do |order_my_warehouse|
        if Order.where(:uuid => order_my_warehouse["uuid"]).blank?
          Order.create(:uuid => order_my_warehouse["uuid"],
                       :good_id => order_my_warehouse['customerOrderPosition']['goodUuid'],
                       :agent_id => order_my_warehouse['customerOrderPosition']['sourceAgentUuid'],
                       :quantity => order_my_warehouse['customerOrderPosition']['quantity'],
                       :base_price => order_my_warehouse['customerOrderPosition']['basePrice'],
                       :sum => order_my_warehouse['customerOrderPosition']['sum'])

        else
          query = Order.find_by(:uuid => order_my_warehouse["uuid"])
          query.update(:good_id => order_my_warehouse['customerOrderPosition']['goodUuid'],
                       :agent_id => order_my_warehouse['customerOrderPosition']['sourceAgentUuid'],
                       :quantity => order_my_warehouse['customerOrderPosition']['quantity'],
                       :base_price => order_my_warehouse['customerOrderPosition']['basePrice'],
                       :sum => order_my_warehouse['customerOrderPosition']['sum'])

        end
      end
    end
    return orders_my_warehouse
  end

  def self.delete_orders(orders_my_warehouse)
    @orders = Order.all
    @orders.each do |order|
      if (orders_my_warehouse.select {|hash| hash["uuid"] == order.uuid }).blank?
        Order.delete(order.id)
        puts "Order deleted"
      end
    end
  end

  def self.moy_sklad_get(entityType, uuid, company)
    moy_sklad_request(entityType, uuid, nil, :get, company["moy_sklad_login"], company["moy_sklad_password"])
  end

  def self.moy_sklad_request(entityType, entityId, xml, request_type, login, password)
    http = Net::HTTP.new("online.moysklad.ru", 443)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    url = "/exchange/rest/ms/xml/" + entityType
    if [:get, :delete].include?(request_type) && entityId
      url += "/#{entityId}"
    end

    if request_type == :put
      request = Net::HTTP::Put.new(url)
    elsif request_type == :post
      request = Net::HTTP::Post.new(url)
    elsif request_type == :delete
      request = Net::HTTP::Delete.new(url)
    else
      request = Net::HTTP::Get.new(url)
    end

    request.basic_auth(login, password)
    request["Host"] = 'online.moysklad.ru'
    request["Content-Type"] = 'application/xml'
    request["Accept"] = '*/*'
    request["Connection"] = 'close'

    request.body = xml
    response = http.request(request)
    while response.kind_of? Net::HTTPTooManyRequests
      sleep 0.2
      response = http.request(request)
    end

    if response.kind_of? Net::HTTPBadGateway  # Give it one more try
      response = http.request(request)
    end

    return response

  end
end
