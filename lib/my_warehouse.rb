require 'builder'
require 'nokogiri'
require 'net/http'

module MyWarehouse

  def self.upload_orders
    company = {"moy_sklad_login" => "admin@morozovaleksey", "moy_sklad_password" => "e7c625909866" }
    response = moy_sklad_get('CustomerOrder','list', company)
    doc = Nokogiri::XML(response.body)
    @orders_my_warehouse = doc.xpath('//collection/customerOrder').map do |i|
      {'uuid' => i.xpath('uuid').text(),'groupUuid' => i.xpath('groupUuid').text(),
       'customerOrderPosition' => {'quantity' => i.xpath('customerOrderPosition/@quantity').text(),
                                   'goodUuid' => i.xpath('customerOrderPosition/@goodUuid').text(),
                                   'basePrice' =>i.xpath('customerOrderPosition/basePrice/@sum').text(),
                                   'sourceAgentUuid' => i.xpath('@sourceAgentUuid').text() },
      }

    end
    puts "Orders parsed"
    unless @orders_my_warehouse.blank?
      @orders_my_warehouse.each do |order_my_warehouse|
        if Order.where(:uuid => order_my_warehouse["uuid"]).blank?
          Order.create(:uuid => order_my_warehouse["uuid"],
                       :good_id => order_my_warehouse['customerOrderPosition']['goodUuid'],
                       :agent_id => order_my_warehouse['customerOrderPosition']['sourceAgentUuid'],
                       :quantity => order_my_warehouse['customerOrderPosition']['quantity'])
          puts "Order created"
        else
          query = Order.find_by(:uuid => order_my_warehouse["uuid"])
          query.update(:good_id => order_my_warehouse['customerOrderPosition']['goodUuid'],
                       :agent_id => order_my_warehouse['customerOrderPosition']['sourceAgentUuid'],
                       :quantity => order_my_warehouse['customerOrderPosition']['quantity'])
          puts "Order updated"
        end

      end
      delete_orders(@orders_my_warehouse)

    end

  end

  def self.delete_orders(orders_my_warehouse)
    @orders = Order.all
    @orders.each do |order|
      unless orders_my_warehouse.select {|hash| hash["uuid"] == order.uuid }
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
