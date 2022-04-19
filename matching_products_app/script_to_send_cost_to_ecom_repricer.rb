user = User.find_by(email: "docsalesllc@heonboard.com")
user.switch!


account = Account.find_by(marketplace_partner_id: 'A36CKLEC46FGAN')
repricer_data = []
repricer_data << {marketplace_account_id: account.marketplace_partner_id, products: []}

wholesale_platform_ids = Platform.wholesale.ids
amazon_listings = account.amazon_listings.uploaded.where(is_mismatch: [false, nil], disable_feeds: false).joins(:amazon_suppliers).where('amazon_suppliers.is_default = ?', true);nil
if account.repricer_external?
  index = 0
  amazon_listings.find_each do |amz_listing|
    puts index + 1
    index += 1
    # amz_listing = AmazonListing.find_by(sku: '04182022_1437')
    supplier = amz_listing.default_supplier
    next if supplier.blank?

    platform = supplier.platform
    setting = platform.setting

    price_with_multiplier = supplier.price * [supplier.quantity_multiplier.to_i, 1].max
    next if price_with_multiplier.zero?

    shipping_fee = [supplier.shipping_fee.to_f, setting&.shipping_fee.to_f].max
    shipping_fee = setting&.non_prime_shipping.to_f if setting&.name == 'amazon' &&
                                                          !setting&.has_prime_acc &&
                                                          price_with_multiplier < 25.0 &&
                                                          supplier.shipping_fee.to_f.zero?
    
    price_with_multiplier += ([supplier.quantity_multiplier.to_i, 1].max * account.warehouse_charges.to_f) + 3.5 if wholesale_platform_ids.exclude?(supplier.platform_id) && !amz_listing.mp_fi && (supplier.ship_to_warehouse || account.two_step_enabled)
    partner_id_row = repricer_data.find{|a| a[:marketplace_account_id] == account.marketplace_partner_id}
    partner_id_row[:products] << {sku: amz_listing.sku, cost: price_with_multiplier.round(2), shipping_fee: shipping_fee, tag: supplier.name}
  end;nil
end


def send_data_to_repricer(repricer_data, api_key_repricer, listed_on)
  response = {}
  ## repricer apis are separate for both walmart & amazon
  api_url = listed_on == 'walmart' ? 'update_supplier_cost' : 'amazon/products/update_cost/'
  begin
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Token #{api_key_repricer}"
    }
    response = RestClient.post("https://repricer.ecomcircles.com/api/v1/#{api_url}", { data: repricer_data }.to_json, headers)
  rescue Exception => e
    File.open("public/repricer_api_failed_#{Apartment::Tenant.current}_#{DateTime.now.strftime('%Y%m%d%H%M%S')}.json", 'w') {|file| file.write repricer_data.to_json}
    CodeException.insert_exception('Send Cost Repricer ECS READER', e, {listed_on: listed_on})
  end
  response
end

response = send_data_to_repricer(repricer_data, user.api_key_repricer, 'amazon')
JSON.parse response.body

