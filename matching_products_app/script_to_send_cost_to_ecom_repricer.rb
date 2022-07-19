user = User.find_by(email: 'theredmonkeystorellc@gmail.com')
user.switch!

AccountsProduct.where(account_id: 31, sku: 'GINnac600').first
AccountsProduct.where(account_id: 31, sku: 'GINnac600').first.default_supplier

repricer_data = []
Account.enabled.valid.active.repricer_external.each do |account|
  next if account.marketplace_partner_id.blank?
  
  # repricer_data << {marketplace_account_id: account.marketplace_partner_id, products: []}
  products = []
  if account.walmart?
    index = 0
    listed_on = 'walmart'
    account.accounts_products.uploaded.
    where(is_mismatch: [false, nil]).
    joins(:suppliers).where('suppliers.is_default = ?', true).
    find_each do |wm_listing|
      puts index + 1
      index += 1
      supplier = wm_listing.default_supplier
      next if supplier.blank?

      platform = supplier.platform
      setting = platform.setting

      price_with_multiplier, shipping_fee = total_price_plus_shipping(supplier, setting)
      next if price_with_multiplier.zero?
      
      price_with_multiplier += ([supplier.quantity_multiplier.to_i, 1].max * account.warehouse_charges.to_f) + 3.5 if !wm_listing.mp_fi && (supplier.ship_to_warehouse || account.two_step_enabled)
      products << {sku: wm_listing.sku, cost: price_with_multiplier.round(2), shipping_fee: shipping_fee.round(2), tag: supplier.name}
    end;nil
  else
    index = 0
    listed_on = 'amazon'
    products = []
    account.amazon_listings.uploaded.
    where(is_mismatch: [false, nil]).
    joins(:amazon_suppliers).where('amazon_suppliers.is_default = ?', true).find_each do |amz_listing|
      puts index + 1
      index += 1
      supplier = amz_listing.default_supplier
      next if supplier.blank?

      platform = supplier.platform
      setting = platform.setting

      price_with_multiplier, shipping_fee = total_price_plus_shipping(supplier, setting)
      next if price_with_multiplier.zero?

      price_with_multiplier += ([supplier.quantity_multiplier.to_i, 1].max * account.warehouse_charges.to_f) + 3.5 if !amz_listing.mp_fi && (supplier.ship_to_warehouse || account.two_step_enabled)
      products << {sku: amz_listing.sku, cost: price_with_multiplier.round(2), shipping_fee: shipping_fee.round(2), tag: supplier.name}
    end
  end

  products.in_groups_of(1000, false).each_with_index do |products_batch, index|
    puts index
    final_arr = {marketplace_account_id: account.marketplace_partner_id, products: products_batch}
    response = send_data_to_repricer(final_arr, user.api_key_repricer, listed_on)
    pp JSON.parse response.body
  end
  

  response = send_data_to_repricer(repricer_data, user.api_key_repricer, listed_on)
  pp JSON.parse response.body

  skus = products.map{|a| a[:sku]}.compact
  if account.walmart?
    AccountsProduct.where(account_id: account.id).where(sku: skus).
    update_all(price_changed: false, price_updated_at: Time.now) if response.present? && response.code == 200
  else
    AmazonListing.where(account_id: account.id).where(sku: skus).
    update_all(price_changed: false, price_updated_at: Time.now) if response.present? && response.code == 200
  end
end

def total_price_plus_shipping(supplier, setting)
  price_with_multiplier = supplier.price * [supplier.quantity_multiplier.to_i, 1].max
  shipping_fee = prioritised_shipping_fee(supplier, setting)
  shipping_fee = setting&.non_prime_shipping.to_f if setting&.name == 'amazon' &&
                                                            !setting&.has_prime_acc &&
                                                            price_with_multiplier < 25.0 &&
                                                            supplier.shipping_fee.to_f.zero?
  [price_with_multiplier, shipping_fee]
end

def prioritised_shipping_fee(supplier, setting)
  if supplier.shipping_fee_lock
    supplier.manual_shipping_fee
  elsif setting&.shipping_fee_lock
    setting&.shipping_fee
  else
    supplier.shipping_fee
  end
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
    # JSON.parse ({ data: repricer_data.to_json }.to_json)
    response = Mechanize.new.post("https://repricer.ecomcircles.com/api/v1/#{api_url}", { 'data' => repricer_data}.to_json, headers)
    response = RestClient.post("https://repricer.ecomcircles.com/api/v1/#{api_url}", { 'data' => repricer_data }, headers)
  rescue Exception => e
    File.open("public/repricer_api_failed_#{Apartment::Tenant.current}_#{DateTime.now.strftime('%Y%m%d%H%M%S')}.json", 'w') {|file| file.write repricer_data.to_json}
    CodeException.insert_exception('Send Cost Repricer ECS READER', e, {listed_on: listed_on})
  end
  response
end


