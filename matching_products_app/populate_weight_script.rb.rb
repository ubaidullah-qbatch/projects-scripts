fp = '/Users/apple/Downloads/rsw_weight.json'
arr = JSON.parse(File.read(fp))

arr.map{|a| a['weightUnit']}.compact.tally

arr.select{|a| a['weightUnit'] == 'g'}.each do |row|
  pound_weight = Product.convert_weight_to_pounds(row['weightUnit'].upcase, row['packageWeight'])
  row['weightUnit'] = 'pounds'
  row['packageWeight'] = pound_weight
end;nil

wholesale_ids = Platform.wholesale.ids
group_by_arr = arr.group_by{|a| a['packageWeight']}
c = 0
group_by_arr.each do |packageWeight, arr_batch|
  # packageWeight, arr_batch = group_by_arr.first
  item_ids = arr_batch.map{|a| a['wmIdentifier']}
  puts "#{packageWeight} --- item_ids: #{item_ids.count}"
  item_ids.in_groups_of(2000, false).each_with_index do |item_ids_batch, index|
    # c += AccountsProduct.where(account_id: 31, item_id: item_ids_batch, weight: nil).joins(:suppliers).where("is_default = ? AND suppliers.platform_id NOT IN (?)", true, wholesale_ids).count
    # puts "total count: #{c}"
    c += AccountsProduct.where(account_id: 31, item_id: item_ids_batch, weight: nil).joins(:suppliers).where("is_default = ? AND suppliers.platform_id NOT IN (?)", true, wholesale_ids).update_all(weight_unit: 'POUND', weight: packageWeight)
    puts "total updated count: #{c}"
  end
end



emails = ["matt@sceptermarketing.com", "farrisjoshua@gmail.com", "wnewporti@yahoo.com", "smartdealshoppers@gmail.com", "bluebuckventures@gmail.com", "jlouglobalenterprises@gmail.com"]
User.where(email: emails).each do |user|
  Apartment::Tenant.switch(user.tenant_name) do
    AccountsProduct.where.not(weight: [nil, 0]).where.not(weight_unit: 'POUND').select("id, product_id, sku, account_id, platform_id, weight_unit, weight").find_in_batches do |listings_batch|
      listings_arr = JSON.parse(listings_batch.to_json)
      listings_arr.each do |listing_row|
        weight_in_pounds = Product.convert_weight_to_pounds(listing_row['weight_unit'], listing_row['weight'])
        if weight_in_pounds
          listing_row['weight_unit'] = 'POUND'
          listing_row['weight'] = weight_in_pounds.to_f
        end
      end;nil
      AccountsProduct.import ["id", "account_id", "product_id", "platform_id", "sku", "weight_unit", "weight"], listings_arr, on_duplicate_key_update: ["weight_unit", "weight"]
    end
  end
end



# listings_batch = AccountsProduct.where.not(weight: [nil, 0]).where.not(weight_unit: 'POUND').select("id, product_id, sku, account_id, platform_id, weight_unit, weight").limit 1000
arr = []
User.active.each do |user|
  Apartment::Tenant.switch(user.tenant_name) do
    wm_c = AccountsProduct.where.not(weight: [nil, 0]).where.not(weight_unit: 'POUND').count
    amz_c = AmazonListing.where.not(weight: [nil, 0]).where.not(weight_unit: 'POUND').count
    arr << {email: user.email, wm_c: wm_c, amz_c: amz_c} if wm_c.positive? || amz_c.positive?
  end;nil
end;nil


