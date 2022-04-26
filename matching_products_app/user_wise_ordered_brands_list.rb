User.active.each_with_index do |user, index|
  puts index
  Apartment::Tenant.switch(user.tenant_name) do
    for_wm, for_amz = [], []
    AccountsProduct.where(first_order_received: true).joins(:product).select("accounts_products.id, IF(accounts_products.brand IS NOT NULL, accounts_products.brand, products.brand) as brand").find_in_batches do |listings_batch|
      for_wm += listings_batch.map{|a| a.brand}.compact
    end
    AmazonListing.where(first_order_received: true).joins(:product).select("amazon_listings.id, IF(amazon_listings.brand IS NOT NULL, amazon_listings.brand, products.brand) as brand").find_in_batches do |listings_batch|
      for_amz += listings_batch.map{|a| a.brand}.compact
    end
    for_wm.compact!;nil
    for_wm.uniq!;nil
    for_amz.compact!;nil
    for_amz.uniq!;nil
    brands_data = {email: user.email, for_wm: for_wm, for_amz: for_amz}
    File.open("public/user_wise_ordered_brands_list/#{user.email}.json", 'w') { |f| f.write brands_data.to_json }
  end
end;nil