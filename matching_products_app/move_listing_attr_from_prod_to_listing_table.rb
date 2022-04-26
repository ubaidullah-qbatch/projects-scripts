# Write script to move following listing attributes from product to listing & supplier
# list price, brand, upc, main cat, sub cat, weight, supplier price

## WALMART SCRIPT ##
User.active.each do |user|
  Apartment::Tenant.switch(user.tenant_name) do
    ap_arr, sup_arr = [], []
    wm_account_ids = Account.walmart.enabled.valid.active.ids
    next if wm_account_ids.blank?

    AccountsProduct.where(listing_status: [:added, :pending_upload, :errored], account_id: wm_account_ids).joins(:suppliers).where("is_default = ?", true).
    where("upc IS NULL OR upc != ? OR brand IS NULL OR brand != ? OR weight IS NULL OR weight = ? OR price IS NULL OR price = ?", '', '', 0, 0).
    select("accounts_products.id, product_id, account_id, sku, item_id, upc, brand, weight, weight_unit, accounts_products.last_submitted_price, accounts_products.platform_id as ap_platform_id, suppliers.id as sup_id, suppliers.price as sup_price, accounts_product_id, suppliers.platform_id as sup_platform_id, suppliers.name as sup_name").find_in_batches do |listings_batch|
      listings_batch.each do |ap|
        ap_arr << {id: ap.id, product_id: ap.product_id, account_id: ap.account_id, sku: ap.sku, item_id: ap.item_id, platform_id: ap.ap_platform_id, upc: ap.upc, brand: ap.brand, last_submitted_price: ap.last_submitted_price, weight_unit: ap.weight_unit, weight: ap.weight}
        sup_arr << {id: ap.sup_id, accounts_product_id: ap.accounts_product_id, platform_id: ap.sup_platform_id, price: ap.sup_price, name: ap.sup_name}
      end
    end
    p_ids = ap_arr.map{|a| a[:product_id]}.compact.uniq
    puts "PRODUCT IDS COUNT: #{p_ids.count}"
    p_ids.in_groups_of(5000, false).each_with_index do |ids_batch, index|
      puts "ITERATION: #{index+1}"
      ii = 0
      listings_subset = ap_arr.select{|a| ids_batch.include?(a[:product_id])}
      Product.where(id: ids_batch).find_each do |src_product|
        listing_data = listings_subset.select{|a| a[:product_id] == src_product.id}
        puts "inner iteration: #{ii+1}"
        ii += 1
        listing_data.each do |listing_row|
          listing_row[:upc] = listing_row[:upc].blank? ? src_product.upc : listing_row[:upc]
          listing_row[:brand] = listing_row[:brand].blank? ? src_product.brand : listing_row[:brand]
          listing_row[:main_category] = listing_row[:main_category].blank? ? src_product.main_category : listing_row[:main_category]
          listing_row[:sub_category] = listing_row[:sub_category].blank? ? src_product.sub_category : listing_row[:sub_category]
          listing_row[:last_submitted_price] = listing_row[:last_submitted_price].to_f.zero? ? src_product.product_hash.to_h.dig('list_price').to_f : listing_row[:last_submitted_price]
          listing_row[:weight_unit] = listing_row[:weight_unit].blank? ? 'POUND' : listing_row[:weight_unit]
          listing_row[:weight] = listing_row[:weight].to_f.zero? ? src_product.item_weight.round(2) : listing_row[:weight]
        end
        accounts_product_ids = listing_data.map{|a| a[:id]}
        supplier_data = sup_arr.select{|a| accounts_product_ids.include?(a[:accounts_product_id])}
        supplier_data.each do |supplier_row|
          supplier_row[:price] = supplier_row[:price].to_f.zero? ? src_product.price.to_f : supplier_row[:price]
        end
      end
    end

    ap_arr.in_groups_of(5000, false).each_with_index do |listings_batch, index|
      AccountsProduct.import! [:id, :account_id, :platform_id, :sku, :upc, :brand, :last_submitted_price, :weight_unit, :weight], listings_batch, on_duplicate_key_update: [:upc, :brand, :last_submitted_price, :weight_unit, :weight]
    end

    sup_arr.in_groups_of(5000, false).each_with_index do |suppliers_batch, index|
      Supplier.import! [:id, :accounts_product_id, :platform_id, :price], suppliers_batch, on_duplicate_key_update: [:price]
    end
  end
end


## AMAZON SCRIPT ##
User.active.each do |user|
  Apartment::Tenant.switch(user.tenant_name) do
    ap_arr, sup_arr = [], []
    amz_account_ids = Account.walmart.enabled.valid.active.ids
    next if amz_account_ids.blank?

    AmazonListing.where(listing_status: [:added, :pending_upload, :errored], account_id: amz_account_ids).joins(:amazon_suppliers).where("is_default = ?", true).
    where("brand IS NULL OR brand != ? OR price IS NULL OR price = ?", '', 0).
    select("amazon_listings.id, product_id, account_id, sku, item_id, upc, brand, weight, weight_unit, amazon_listings.last_submitted_price, amazon_suppliers.id as sup_id, amazon_suppliers.price as sup_price, amazon_listing_id, amazon_suppliers.platform_id as sup_platform_id, amazon_suppliers.name as sup_name").find_in_batches do |listings_batch|
      listings_batch.each do |ap|
        ap_arr << {id: ap.id, product_id: ap.product_id, account_id: ap.account_id, sku: ap.sku, item_id: ap.item_id, brand: ap.brand, last_submitted_price: ap.last_submitted_price}
        sup_arr << {id: ap.sup_id, amazon_listing_id: ap.amazon_listing_id, platform_id: ap.sup_platform_id, price: ap.sup_price, name: ap.sup_name}
      end
    end
    p_ids = ap_arr.map{|a| a[:product_id]}.compact.uniq
    puts "PRODUCT IDS COUNT: #{p_ids.count}"
    p_ids.in_groups_of(5000, false).each_with_index do |ids_batch, index|
      puts "ITERATION: #{index+1}"
      ii = 0
      listings_subset = ap_arr.select{|a| ids_batch.include?(a[:product_id])}
      Product.where(id: ids_batch).find_each do |src_product|
        listing_data = listings_subset.select{|a| a[:product_id] == src_product.id}
        puts "inner iteration: #{ii+1}"
        ii += 1
        listing_data.each do |listing_row|
          listing_row[:brand] = listing_row[:brand].blank? ? src_product.brand : listing_row[:brand]
          listing_row[:main_category] = listing_row[:main_category].blank? ? src_product.main_category : listing_row[:main_category]
          listing_row[:sub_category] = listing_row[:sub_category].blank? ? src_product.sub_category : listing_row[:sub_category]
          listing_row[:last_submitted_price] = listing_row[:last_submitted_price].to_f.zero? ? src_product.product_hash.to_h.dig('list_price').to_f : listing_row[:last_submitted_price]
        end
        accounts_product_ids = listing_data.map{|a| a[:id]}
        supplier_data = sup_arr.select{|a| accounts_product_ids.include?(a[:accounts_product_id])}
        supplier_data.each do |supplier_row|
          supplier_row[:price] = supplier_row[:price].to_f.zero? ? src_product.price.to_f : supplier_row[:price]
        end
      end
    end

    ap_arr.in_groups_of(5000, false).each_with_index do |listings_batch, index|
      AmazonListing.import! [:id, :account_id, :platform_id, :sku, :upc, :brand, :last_submitted_price, :weight_unit, :weight], listings_batch, on_duplicate_key_update: [:upc, :brand, :last_submitted_price, :weight_unit, :weight]
    end

    sup_arr.in_groups_of(5000, false).each_with_index do |suppliers_batch, index|
      AmazonSupplier.import! [:id, :accounts_product_id, :platform_id, :price], suppliers_batch, on_duplicate_key_update: [:price]
    end
  end
end