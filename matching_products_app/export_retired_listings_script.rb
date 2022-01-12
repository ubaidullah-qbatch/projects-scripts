# AccountsProduct.retired.group(:is_mismatch).count
def make_marketplace_url(item_id)
  return if item_id.blank?
  case @platform.name
  when 'walmart'
    "https://www.walmart.com/ip/#{item_id}"
  when 'amazon'
    "https://www.amazon.com/dp/#{item_id}"
  end
end

# AccountsProduct.where(account_id: 23).group(:listing_status).count
User.find(3).switch!

h = AccountsProduct.retired.joins(:suppliers).where("is_default = ?", true).group("accounts_product_id").having("count(*) = 1").count
ap_ids = h.keys.uniq
# AccountsProduct.retired.joins(:suppliers).where("is_default = ?", true).group(:error_type).count

# is_mismatch
# ma_price
# va_id
# listing_source user/shared/system listings

attributes = ["SKU", "UPC", "Supplier Url", "Marketplace Url", "Verified Match", "Is Default", "Quantity Multiplier", "Item Id", "Listed Price", "Supplier Price", "Supplier Stock", "Supplier Shipping", "Variation", "Is Mismatch", "Ma Price", "Va Id", "Listing Source", "Error Type", "Error Log"]
@platform = Platform.find_by(name: 'walmart')
listings_klass, suppliers_klass = Platform.set_listing_and_supplier(@platform)
listings_table_name = listings_klass.constantize.table_name
suppliers_table_name = suppliers_klass.constantize.table_name
have_buy_box = "IF ((#{listings_table_name}.last_submitted_stock > 0 AND won_buybox = TRUE), TRUE, FALSE) AS won_buybox"
csv_data = CSV.generate(headers: true) do |csv|
  csv << attributes
  ap_ids.in_groups_of(1000, false).each_with_index do |ids_batch, index|
    puts "iteration: #{index}"
    listings_json = JSON.parse(AccountsProduct.where(id: ids_batch).joins(:suppliers).select("#{listings_table_name}.id, #{listings_table_name}.sku, #{listings_table_name}.upc, #{listings_table_name}.auto_ordering_enabled, #{suppliers_table_name}.quantity_multiplier, #{listings_table_name}.item_id, #{listings_table_name}.is_mismatch, #{suppliers_table_name}.name, #{suppliers_table_name}.url, #{suppliers_table_name}.is_default, #{suppliers_table_name}.price, #{listings_table_name}.last_submitted_price, #{suppliers_table_name}.manual_price, #{suppliers_table_name}.price_lock, #{suppliers_table_name}.stock, #{listings_table_name}.last_submitted_stock, #{listings_table_name}.va_id, #{suppliers_table_name}.manual_stock, #{suppliers_table_name}.stock_lock, #{suppliers_table_name}.shipping_fee, #{suppliers_table_name}.platform_id, #{suppliers_table_name}.variation, #{listings_table_name}.created_at as created_at, #{suppliers_table_name}.refreshed_at as refreshed_at, #{Supplier::OFFRER_STATUS_MAPPING}, #{listings_table_name}.is_mismatch, #{listings_table_name}.va_id, #{listings_table_name}.ma_price, #{listings_table_name}.listing_source, #{listings_table_name}.error_type, #{listings_table_name}.error_log").to_json)
    listings_json.each do |listing|
      auto_ordering_enabled = listing['auto_ordering_enabled'] ? 1 : 0
      is_default = listing['is_default'] ? 1 : 0
      csv << [listing['sku'], listing['upc'], listing['url'], make_marketplace_url(listing['item_id']), 
      auto_ordering_enabled, is_default, listing['quantity_multiplier'], listing['item_id'], 
      listing['last_submitted_price'], listing['price'], listing['stock'], listing['shipping_fee'], 
      listing['variation'], listing['is_mismatch'], listing['ma_price'], listing['va_id'], listing['listing_source'],
      listing['error_type'], listing['error_log']]
    end
  end
end
full_name = "backup_matt_walmart_retired_listings_#{DateTime.now.strftime('%Y%m%d%H%M%S')}.csv"
File.open("#{Rails.root.to_s}/public/#{full_name}", 'w') { |f| f.write csv_data }

csv = CSV.parse(File.read("#{Rails.root.to_s}/public/#{full_name}"), headers: true)
csv.count


## 
# ap_ids.last(100).each_with_index do |id, index|
#   puts "#{index} -- #{Supplier.where(accounts_product_id: id).count}"
# end