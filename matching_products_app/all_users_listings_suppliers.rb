arr = []
User.active.each do |user|
  Apartment::Tenant.switch(user.tenant_name) do
    amz_active_accounts = Account.amazon.refreshable.ids
    wm_active_accounts = Account.walmart.refreshable.ids
    refreshable_platforms_ids = Platform.where(name: Platform::REFRESHABLE_PLATFORMS_NAMES + Platform::SKUGRID_REFRESHABLE_PLATFORMS_NAMES).pluck(:id)
    wm_stats = Supplier.joins(:accounts_product).where(platform_id: refreshable_platforms_ids).where(accounts_products: {account_id: wm_active_accounts, disable_feeds: false, listing_status: :uploaded}).group(:name).count
    amz_stats = AmazonSupplier.joins(:amazon_listing).where(platform_id: refreshable_platforms_ids).where(amazon_listings: {account_id: amz_active_accounts, disable_feeds: false, listing_status: :uploaded}).group(:name).count
    arr << {email: user.email, walmart_listing: wm_stats, amazon_listing: amz_stats}
  end
end;nil


CSV.open("public/all_users_listings_suppliers.csv", "w") do |csv|
  csv << arr.first.keys.map(&:to_s).map(&:humanize).map(&:upcase)
  arr.select{|r| r[:walmart_listing].present? || r[:amazon_listing].present? }.each do |r|
    csv << r.values
  end;nil
end;nil
csv = CSV.parse(File.read('public/all_users_listings_suppliers.csv'), headers: true)