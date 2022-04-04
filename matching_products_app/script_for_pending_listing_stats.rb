# users listings stuck due to price brand upc
# per user & global stats
# what is per user & global pending listings count that are in added, pending_upload, errored status
# sum of stuck listings should be equal to total
# group by error_type remaining ones that are not filtered in any condition

##### AMAZON #######
global = []
User.active.each_with_index do |user, index|
  puts "#{user.email} -- #{index}"
  Apartment::Tenant.switch(user.tenant_name) do
    accounts_ids = Account.amazon_with_keys.enabled.valid.ids
    listings_arr = JSON.parse(AmazonListing.where(listing_status: [:added, :pending_upload]).where(account_id: accounts_ids).joins(:product).where("amazon_listings.created_at < ?", 1.hour.ago).select("listing_status, error_type, products.price, products.brand, products.upc, sku, account_id, listing_feed_error").to_json)
    brand_restricted = listings_arr.select{|a| a['error_type'] == 'brand_restricted' }.count
    system_error = listings_arr.select{|a| a['error_type'] == 'system_error' }.count
    product_not_available = listings_arr.select{|a| a['error_type'] == 'product_not_available' }.count
    no_error = listings_arr.select{|a| a['error_type'].blank? }.count
    missing_price_only = listings_arr.select{|a| a['error_type'] != 'brand_restricted' && a['price'].to_f.zero? && a['brand'].present? }.count
    missing_brand_only = listings_arr.select{|a| a['error_type'] != 'brand_restricted' && a['brand'].blank? && a['price'].to_f.positive?}.count
    missing_both = listings_arr.select{|a| a['error_type'] != 'brand_restricted' && a['brand'].blank? && a['price'].to_f.zero? }.count
    both_present_still_pending = listings_arr.select{|a| a['error_type'] != 'brand_restricted' && a['price'].to_f.positive? && a['brand'].present? }.count
    h = {email: user.email, total: listings_arr.count, brand_restricted: brand_restricted, except_brand_restricted: (listings_arr.count - brand_restricted), missing_price_only: missing_price_only, missing_brand_only: missing_brand_only, missing_both: missing_both, both_present_still_pending: both_present_still_pending} if [missing_price_only, missing_brand_only, missing_both, both_present_still_pending, brand_restricted].any?{|a| a.positive?}
    puts h
    global << h if h.present?
  end;nil
end;nil

overall = {}
global.first.keys[1..-1].each do |key|
  overall.merge!("#{key}" => global.sum{|a| a["#{key}".to_sym]})
end;nil
puts overall


CSV.open("public/pending_listing_stats.csv", "w") do |csv|
  csv << global.first.keys.map(&:to_s).map(&:humanize).map(&:upcase)
  global.each do |r|
    csv << r.values
  end;nil
end;nil



##### WALMART #######

wm_global = []
User.active.where.not(id: 3).each_with_index do |user, index|
  puts "#{user.email} -- #{index}"
  Apartment::Tenant.switch(user.tenant_name) do
    accounts_ids = Account.walmart_with_keys.enabled.valid.ids
    listings_arr = JSON.parse(AccountsProduct.where(listing_status: [:added, :pending_upload]).where(account_id: accounts_ids).joins(:product).where("accounts_products.created_at < ?", 1.hour.ago).select("listing_status, error_type, products.price, products.brand, products.upc, sku, account_id, accounts_products.error_log").to_json)
    brand_restricted = listings_arr.select{|a| a['error_type'] == 'brand_restricted' }.count
    system_error = listings_arr.select{|a| a['error_type'] == 'system_error' }.count
    product_not_available = listings_arr.select{|a| a['error_type'] == 'product_not_available' }.count
    no_error = listings_arr.select{|a| a['error_type'].blank? }.count
    missing_price_only = listings_arr.select{|a| a['error_type'] != 'brand_restricted' && a['price'].to_f.zero? && a['brand'].present? }.count
    missing_brand_only = listings_arr.select{|a| a['error_type'] != 'brand_restricted' && a['brand'].blank? && a['price'].to_f.positive?}.count
    missing_upc_only = listings_arr.select{|a| a['error_type'] != 'brand_restricted' && a['brand'].present? && a['price'].to_f.positive? && a['upc'].blank?}.count
    missing_all = listings_arr.select{|a| a['error_type'] != 'brand_restricted' && a['brand'].blank? && a['price'].to_f.zero? && a['upc'].blank? }.count
    all_present_still_pending = listings_arr.select{|a| a['error_type'] != 'brand_restricted' && a['price'].to_f.positive? && a['brand'].present? && a['upc'].present? }.count
    h = {}
    h.merge!(email: user.email, total: listings_arr.count, brand_restricted: brand_restricted, except_brand_restricted: (listings_arr.count - brand_restricted), missing_upc_only: missing_upc_only, missing_price_only: missing_price_only, missing_brand_only: missing_brand_only, missing_all: missing_all, all_present_still_pending: all_present_still_pending) if [missing_price_only, missing_brand_only, missing_upc_only, missing_all, all_present_still_pending, brand_restricted].any?{|a| a.positive?}
    puts h if h.present?
    wm_global << h if h.present?
  end;nil
end;nil

wm_overall = {}
wm_global.first.keys[1..-1].each do |key|
  wm_overall.merge!("#{key}" => wm_global.sum{|a| a["#{key}".to_sym]})
end;nil
puts wm_overall


CSV.open("public/walmart_pending_listing_stats.csv", "w") do |csv|
  csv << wm_global.first.keys.map(&:to_s).map(&:humanize).map(&:upcase)
  wm_global.each do |r|
    csv << r.values
  end;nil
end;nil