# - check keepa for missing weight listings
AccountsProduct.where(account_id: 27).retired.where("weight IS NULL OR weight = 0").joins(:suppliers).where("is_default = ? AND name = ?", true, 'amazon').group("listing_source").count
# AccountsProduct.where(account_id: 27).retired.joins(:suppliers).where("is_default = ?", true).group("name").count

# - fetch asins,item_ids from suspended accounts EZShope/EDS
arr = []
[18,27].each do |account_id|
  arr += JSON.parse(AccountsProduct.where(account_id: account_id).retired.where("weight IS NULL OR weight = 0").joins(:suppliers).where("is_default = ? AND name = ?", true, 'amazon').select("item_id, url").to_json)
end;nil
arr.uniq!{|a| a['item_id']};nil

# - get data not present on VWM
not_in_vwm_arr = []
arr.in_groups_of(1000, false).each_with_index do |arr_slice, index|
  puts "iteration: #{index}"
  item_ids = AccountsProduct.where(account_id: 23, item_id: arr_slice.map{|a| a['item_id']}.compact.uniq).pluck(:item_id)
  not_in_vwm_arr += arr_slice.reject{|a| item_ids.include? a['item_id']}
end;nil

# save asin 
not_in_vwm_arr.map{|a| a.merge!('asin' => Supplier.asin_from_url(a['url']).to_s.upcase) if a['url'].present?};nil
not_in_vwm_arr.select{|a| a['asin'].blank?}.count
not_in_vwm_arr.reject!{|a| a['asin'].blank?};nil

# save not present on VWM in file 
File.open("public/matches_from_ezshope_eds_not_in_vwm.json", 'w') {|file| file.write not_in_vwm_arr.to_json}
not_in_vwm_arr1 = JSON.parse(File.read('public/matches_from_ezshope_eds_not_in_vwm.json'))

# run keepa to save asins keepa object for not present on VWM in file
asins = not_in_vwm_arr1.map{|a| a['asin']}.compact.uniq
file_dir = Rails.root.to_s + "/public/keepa_response"
FileUtils::mkdir_p file_dir unless File.directory?(file_dir)
asins.in_groups_of(99).each_with_index do |asins_batch, index|
  begin
    puts "iteration: #{index} --- #{99*(index+1)}/#{asins.count} processed"
    full_url = "https://api.keepa.com/product?key=#{ENV['KEEPA_API_KEY']}&domain=1"
    full_url += "&asin=#{asins_batch.to_csv}"

    response = HTTParty.get(full_url)
    keepa_products = response["products"] || []
    keepa_products.each do |keepa_product|
      File.open("#{file_dir}/#{keepa_product['asin']}", 'w') { |f| f.write keepa_product.to_json }
    end
    sleep(response["refillIn"].to_i/1000.to_f) unless response["tokensLeft"].to_i > 99
  rescue => e
    puts "#{index}------------#{e.message}"
  end
end

# update keepa weight of all items in lisitngs
files = Dir["public/keepa_response/*"]
data = []

files.each_with_index do |file, index|
  puts"---------___#{index}"
  keepa_obj = JSON.parse(File.read(file))
  packageWeight = (keepa_obj["packageWeight"]/454.00).round(2)
  packageWeightGrams = (keepa_obj["packageWeight"]).round(2)
  itemWeight = (keepa_obj["itemWeight"]/454.00).round(2)
  itemWeightGrams = (keepa_obj["itemWeight"]).round(2)
  asin = keepa_obj["asin"]
  item_id = not_in_vwm_arr1.find{|a| a['asin'] == asin}.dig('item_id')
  data << { packageWeight: packageWeight, item_id: item_id}
end;nil

listable = data.select{|d| d[:packageWeight] > 0 && d[:packageWeight] <= 1};nil
grouped_data = listable.group_by{|l| l[:packageWeight]}
grouped_data.keys.each_with_index do |weight, index|
  puts index
  next if weight <= 0
  
  item_ids = grouped_data[weight].map{|a| a[:item_id] }
  AccountsProduct.where(account_id: [18,27]).retired.where("weight IS NULL OR weight = 0").where(item_id: item_ids).joins(:suppliers).where("is_default = ? AND name = ?", true, 'amazon').update_all(weight_unit: "POUND", weight: weight)
end


## generate csv for all data you need to copy to other account & bulk import csv file
item_ids = listable.map{|a| a[:item_id]}.compact.uniq
listing_platform = Platform.find_by(name: 'walmart')
@listing_platform_id = listing_platform.id
@listing_platform_name = listing_platform.name
@listings_klass = 'AccountsProduct'
data_arr, already_listed = [], 0
@account = Account.find_by(id: 23)
[27,18].each do |account_id|
  item_ids.in_groups_of(1000, false).each_with_index do |item_ids_batch, index|
    puts "iteration: #{index}"
    ## get all attributes I need to copy
    export_arr = AccountsProduct.where(account_id: account_id).retired.where(item_id: item_ids_batch).joins(:product, :suppliers).where("is_default = ? AND name = ?", true, 'amazon').
    select("products.upc, accounts_products.upc as walmart_upc, products.brand, accounts_products.brand as walmart_brand, 
      products.marketplace_id as supplier_id, accounts_products.item_id as marketplace_id, suppliers.name as source_platform_name,
      products.platform_id as source_platform_id, products.source as source_name, products.price as supplier_price,
      products.shipping_fee as supplier_shipping_fee, suppliers.url as supplier_url, suppliers.quantity_multiplier,
      accounts_products.last_submitted_price as list_price, sku, va_id, auto_ordering_enabled, suppliers.variation,
      accounts_products.weight_unit, accounts_products.weight
      ")
    # puts "found items count: #{export_arr.size}"
    export_arr.each_with_index do |record, index|
      src_hash, dest_hash, listing_hash, supplier_hash = process_hash(record)
      data_arr << {src: src_hash, dest: dest_hash, listing: listing_hash, supplier: supplier_hash, index: index}
    end;nil
    unique_by_marketplace_id(data_arr)
    already_listed += reject_already_present_items(data_arr)
    import_data(data_arr)
    data_arr = []
  end
end

## paste all methods before running above script

def import_data(data_arr)
  product_columns = [:marketplace_id, :platform_id, :source, :price, :shipping_fee, :url, :quantity_multiplier, :amz_quantity_multiplier, :origin, :product_hash, :item_weight]
  on_duplicate_update_product_columns = [:price, :shipping_fee, :quantity_multiplier, :amz_quantity_multiplier, :product_hash, :item_weight]

  src_products_arr = []
  data_arr.each{|a| src_products_arr << a.dig(:src)};nil
  create_products(src_products_arr.select{|row| row[:upc].blank?}, product_columns, on_duplicate_update_product_columns);nil
  create_products(src_products_arr.select{|row| row[:upc].present?}, product_columns + [:upc], on_duplicate_update_product_columns + [:upc]);nil

  dest_products_arr = []
  data_arr.each{|a| dest_products_arr << a.dig(:dest)};nil
  create_products(dest_products_arr.select{|row| row[:upc].blank?}, product_columns, on_duplicate_update_product_columns);nil
  create_products(dest_products_arr.select{|row| row[:upc].present?}, product_columns + [:upc], on_duplicate_update_product_columns + [:upc]);nil

  src_marketplace_ids = data_arr.map {|a| a.dig(:src, :marketplace_id)};nil
  dest_marketplace_ids = data_arr.map {|a| a.dig(:dest, :marketplace_id)};nil
  prods = JSON.parse Product.where(marketplace_id: src_marketplace_ids + dest_marketplace_ids).select("id, marketplace_id, platform_id, price").to_json;nil

  matches_arr = []
  data_arr.each do |data_item|
    src = data_item.dig(:src)
    dest = data_item.dig(:dest)
    product_id = prods.find{|b| b['marketplace_id'] == src.dig(:marketplace_id) }['id'] rescue nil
    destination_id = prods.find{|b| b['marketplace_id'] == dest.dig(:marketplace_id) }['id'] rescue nil
    next if product_id.blank? || destination_id.blank?

    matches_arr << {
      product_id: product_id,
      destination_id: destination_id,
      source_platform_id: src.dig(:platform_id),
      platform_id: dest.dig(:platform_id),
      confident_match: true,
      is_manual_match: true,
      review_status: :matched
    }
  end

  create_matches(matches_arr);nil
  listings_arr = JSON.parse(Product.where(marketplace_id: src_marketplace_ids).select("id as product_id, marketplace_id").to_json).map{|prods| prods.except('id')};nil

  suppliers_arr = []
  listings_arr.each do |listing_row|
    data_item = data_arr.map{|a| a if a.dig(:src, :marketplace_id) == listing_row.dig('marketplace_id') }.compact.first
    next if data_item.blank?

    destination_id = prods.find{|b| b['marketplace_id'] == data_item.dig(:dest, :marketplace_id) }['id'] rescue nil
    next if destination_id.blank?

    sku = data_item.dig(:listing, :sku)
    listing_row[:platform_id] = @listing_platform_id if @listing_platform_name == 'walmart'
    listing_row.merge!(
      item_id: data_item.dig(:dest, :marketplace_id),
      account_id: @account.id,
      va_id: data_item.dig(:listing, :va_id),
      auto_ordering_enabled: data_item.dig(:listing, :auto_ordering_enabled),
      listing_status: 'added',
      sku: sku
      )

    data_item.dig(:supplier).merge!(
      sku: sku
    )

    suppliers_arr << data_item.dig(:supplier)
  end

  listings_arr.each(&:deep_symbolize_keys!);nil

  case @listing_platform_name
  when 'walmart'
    create_listings_for_walmart(listings_arr);nil
  when 'amazon'
    create_listings_for_amazon(listings_arr);nil
  end

  listing_ids_and_skus = JSON.parse(@listings_klass.constantize.where(sku: listings_arr.map{|listing_row| listing_row.dig(:sku)}.compact.uniq).select("id, sku").to_json);nil

  listing_ids_and_skus.each do |listing_id_and_sku|
    supplier_data = suppliers_arr.find{|supplier_hash| supplier_hash.dig(:sku) == listing_id_and_sku.dig('sku')}
    next if supplier_data.blank?

    if @listing_platform_name == 'walmart'
      supplier_data.merge!(accounts_product_id: listing_id_and_sku.dig('id'))
    elsif @listing_platform_name == 'amazon'
      supplier_data.merge!(amazon_listing_id: listing_id_and_sku.dig('id'))
    end
  end

  suppliers_arr.map!{|supplier_hash| supplier_hash.except(:sku)};nil

  case @listing_platform_name
  when 'walmart'
    create_suppliers_for_walmart_listings(suppliers_arr);nil
  when 'amazon'
    create_suppliers_for_amazon_listings(suppliers_arr);nil
  end
end



def process_hash(record)
  upc = record.walmart_upc.present? ? record.walmart_upc : upc
  brand = record.walmart_brand.present? ? record.walmart_brand : brand

  src_hash = {}
  dest_hash = {}
  listing_hash = {}
  supplier_hash = {}

  src_hash.merge!(
    upc: upc,
    brand: brand,
    marketplace_id: record.supplier_id,
    platform_id: record.source_platform_id,
    source: record.source_name,
    price: record.supplier_price,
    stock: 0,
    shipping_fee: record.supplier_shipping_fee,
    url: record.supplier_url,
    quantity_multiplier: record.quantity_multiplier,
    amz_quantity_multiplier: 1,
    origin: 'manual',
    product_hash: { "list_price" => record.list_price },
    item_weight: record.weight
    )


  dest_hash.merge!(
    upc: upc,
    brand: brand,
    marketplace_id: record.marketplace_id,
    platform_id: @listing_platform_id,
    source: @listing_platform_name,
    price: record.supplier_price,
    shipping_fee: 0,
    url: "https://www.walmart.com/ip/#{record.marketplace_id}?selected=true",
    quantity_multiplier: 1,
    amz_quantity_multiplier: 1,
    origin: 'manual',
    product_hash: {},
    item_weight: record.weight
  )


  listing_hash.merge!(
    sku: record.sku,
    va_id: record.va_id,
    auto_ordering_enabled: record.auto_ordering_enabled,
    weight_unit: record.weight_unit,
    weight: record.weight
  )

  supplier_hash.merge!(
    platform_id: record.source_platform_id,
    name: record.source_platform_name,
    url: record.supplier_url,
    price: record.supplier_price,
    is_default: true,
    ao_status: true,
    quantity_multiplier: record.quantity_multiplier,
    shipping_fee: record.supplier_shipping_fee,
    stock: 0,
    variation: record.variation,
    refreshed_at: Time.now,
    offer_status: Supplier.offer_statuses['offer_not_refreshed']
  )
  [src_hash, dest_hash, listing_hash, supplier_hash]
end

def unique_by_marketplace_id(data_arr)
  data_arr.uniq!{ |data_item| data_item.dig(:dest, :marketplace_id) }
  #===========
end

def reject_already_present_items(data_arr)
  present_item_ids_and_skus = fetch_already_present_listings(data_arr)
  already_listed = present_item_ids_and_skus.count
  data_arr.reject!{|data_item| present_item_ids_and_skus.map{|a| a[0]}.compact.uniq.any?{|item_id| item_id == data_item.dig(:dest, :marketplace_id)} || present_item_ids_and_skus.map{|a| a[1]}.compact.uniq.any?{|item_id| item_id == data_item.dig(:listing, :sku) } }
  already_listed
end

def fetch_already_present_listings(data_arr)
  item_ids, skus = [], []
  data_arr.map{|data_item| item_ids << data_item.dig(:dest, :marketplace_id); skus << data_item.dig(:listing, :sku) if data_item.dig(:listing, :sku).present? }.compact

  case @listing_platform_name
  when 'walmart'
    present_item_ids_and_skus = AccountsProduct.where(account_id: @account.id).
    where("item_id IN (?) OR sku IN (?)", item_ids, skus).
    where("listing_status IN (?)", [AccountsProduct.listing_statuses['uploaded'], AccountsProduct.listing_statuses['in_progress'], AccountsProduct.listing_statuses['pending_retired'], AccountsProduct.listing_statuses['retired_in_progress']]).
    pluck(:item_id, :sku)
  when 'amazon'
    present_item_ids_and_skus = AmazonListing.where(account_id: @account.id).
    where("item_id IN (?) OR sku IN (?)", item_ids, skus).
    where("listing_status IN (?)", [AmazonListing.listing_statuses['uploaded'], AmazonListing.listing_statuses['in_progress'], AmazonListing.listing_statuses['pending_retired'], AmazonListing.listing_statuses['retired_in_progress']]).
    pluck(:item_id, :sku)
  end

  present_item_ids_and_skus
end

 def create_products(products_arr, columns, on_duplicate_key_update_columns)
    return if products_arr.blank?
    products_arr.in_groups_of(500).each_with_index do |products_batch, index|
      puts "create_products_index: #{index}"
      Product.import columns, products_batch.compact, validate: false, on_duplicate_key_update: on_duplicate_key_update_columns
    end
  end

  def create_matches(matches_arr)
    columns = [:product_id, :destination_id, :source_platform_id, :platform_id, :confident_match, :is_manual_match, :review_status]
    matches_arr.in_groups_of(500).each_with_index do |matches_batch, index|
      puts "create_matches_index: #{index}"
      Match.import columns, matches_batch.compact, validate: false, on_duplicate_key_ignore: true
    end
  end

  def create_listings_for_walmart(listings_arr)
    columns = [:account_id, :platform_id, :product_id, :sku, :listing_status, :item_id, :auto_ordering_enabled, :va_id]
    listings_arr.in_groups_of(500).each_with_index do |listings_batch, index|
      puts "walmart_listings_index: #{index}"
      AccountsProduct.import columns, listings_batch.compact, validate: false, on_duplicate_key_update: [:listing_status, :auto_ordering_enabled, :va_id, :item_id, :product_id]
    end
  end

  def create_listings_for_amazon(listings_arr)
    columns = [:account_id, :product_id, :sku, :listing_status, :item_id, :auto_ordering_enabled, :va_id]
    listings_arr.in_groups_of(500).each_with_index do |listings_batch, index|
      puts "amazon_listings_index: #{index}"
      AmazonListing.import columns, listings_batch.compact, validate: false, on_duplicate_key_update: [:listing_status, :auto_ordering_enabled, :va_id, :item_id, :product_id]
    end
  end

  def create_suppliers_for_walmart_listings(suppliers_arr)
    listing_ids = suppliers_arr.map{|supplier_hash| supplier_hash.dig(:accounts_product_id) };nil
    listing_ids_without_supplier = AccountsProduct.where(id: listing_ids).left_outer_joins(:suppliers).where("suppliers.accounts_product_id IS NULL").pluck(:id);nil
    listing_ids_with_supplier = listing_ids - listing_ids_without_supplier

    no_suppliers_arr = suppliers_arr.select{|supplier_hash| supplier_hash if listing_ids_without_supplier.include?(supplier_hash.dig(:accounts_product_id)) }
    have_suppliers_arr = suppliers_arr.select{|supplier_hash| supplier_hash if listing_ids_with_supplier.include?(supplier_hash.dig(:accounts_product_id)) }

    columns = [:accounts_product_id, :platform_id, :name, :url, :price, :is_default, :ao_status, :quantity_multiplier, :shipping_fee, :stock, :variation, :refreshed_at, :offer_status]
    no_suppliers_arr.in_groups_of(500).each_with_index do |suppliers_batch, index|
      puts "create_suppliers_for_walmart_listings_index: #{index}"
      Supplier.import columns, suppliers_batch.compact, validate: false, on_duplicate_key_update: [:offer_status]
    end

    have_suppliers_arr.each do |supplier_hash|
      Supplier.create(supplier_hash)
    end
  end

  def create_suppliers_for_amazon_listings(suppliers_arr)
    listing_ids = suppliers_arr.map{|supplier_hash| supplier_hash.dig(:amazon_listing_id) }
    listing_ids_without_supplier = AmazonListing.where(id: listing_ids).left_outer_joins(:amazon_suppliers).where("amazon_suppliers.amazon_listing_id IS NULL").pluck(:id)
    listing_ids_with_supplier = listing_ids - listing_ids_without_supplier

    no_suppliers_arr = suppliers_arr.select{|supplier_hash| supplier_hash if listing_ids_without_supplier.include?(supplier_hash.dig(:amazon_listing_id)) }
    have_suppliers_arr = suppliers_arr.select{|supplier_hash| supplier_hash if listing_ids_with_supplier.include?(supplier_hash.dig(:amazon_listing_id)) }

    columns = [:amazon_listing_id, :platform_id, :name, :url, :price, :is_default, :ao_status, :quantity_multiplier, :shipping_fee, :stock, :variation, :refreshed_at, :offer_status]
    no_suppliers_arr.in_groups_of(500).each_with_index do |suppliers_batch, index|
      puts "create_suppliers_for_amazon_listings_index: #{index}"
      AmazonSupplier.import columns, suppliers_batch.compact, validate: false, on_duplicate_key_update: [:offer_status]
    end

    have_suppliers_arr.each do |supplier_hash|
      AmazonSupplier.create(supplier_hash)
    end
  end
