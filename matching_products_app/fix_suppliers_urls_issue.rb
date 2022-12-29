## get users with incorrect supplier urls
users = []
User.not_agency.real_users.each_with_index do |u, index|
  puts "#{u.email} -- #{index}"
  Apartment::Tenant.switch(u.tenant_name) do
    s_cnt = Supplier.joins.where(name: 'other').(:accounts_product).where("listing_status = ?", 2).where("url like ? AND url like ?", "%www.https:%", "%amazon.com%").count
    as_cnt = AmazonSupplier.joins.where(name: 'other').(:amazon_listing).where("listing_status = ?", 2).where("url like ? AND url like ?", "%www.https:%", "%amazon.com%").count
    users << {email: u.email, wm: s_cnt, amz: as_cnt} if s_cnt > 0 || as_cnt > 0
  end;nil
end;nil

## run script to fix urls for found users
incorrect_urls = []
users.each do |row|
  # row = users[2]
  user = User.find_by(email: row[:email])
  next unless user
  puts user.email
  Apartment::Tenant.switch(user.tenant_name) do
    supplier_klass = row[:wm].positive? ? "Supplier" : "AmazonSupplier"
    listing_klass = row[:wm].positive? ? "AccountsProduct" : "AmazonListing"
    p = Platform.find_by(name: "amazon")
    supplier_klass.constantize.where(name: "other").joins(listing_klass.constantize.table_name.singularize.to_sym).where("listing_status = ?", 2).where("url like ?", "%www.https:%").limit(100).find_each do |s|
      if s.url.include?("amazon.com")
        asin = Supplier.asin_from_url(s.url)
        if asin.blank?
          incorrect_urls << s.url
          next
        end
        url = "https://www.amazon.com/dp/#{asin}"
      else
        url = s.url.gsub("https://www.https://www.", "https://www.")
        uri = Addressable::URI.parse url
        platform_name = uri&.domain&.split(".")&.first
        p = Platform.find_by(name: platform_name)
        p = Platform.find_by(name: "other") unless p
      end
      puts "before: #{s.url} --- after: #{url}"
      # s.update_columns(url: url, name: p.name, platform_id: p.id)
    end;nil
  end;nil
end