get 5k system restricted brands from matt acount
minus 1000 manual brands

check remaining against all users & see how many listings users have against those accounts that will potentially be retired if we add these restricted brands in global & for all users


run_brand_stats_script

nohup bundle exec rake walmart_apis:run_brand_stats_script --trace > rake.out 2>&1 &

tail -f rake.out
cat rake.out
: > rake.out

pid = 10905

ps aux | grep run_brand_stats_script
ps aux | grep 10905

arr = JSON.parse(UserBrand.where(marketplace: 'walmart', inventory_restricted: true).joins(:brand).distinct.select("restricted_reason, name").to_json).each{|row| row.delete('id')}
arr.uniq!{|row| row['name']};nil
CSV.open("public/inventory_restricted_brands.csv", "w") do |csv|
  csv << arr.first.keys.map(&:to_s).map(&:humanize).map(&:upcase)
  arr.each do |r|
    csv << r.values
  end;nil
end;nil
csv = CSV.parse(File.read('public/inventory_restricted_brands.csv'), headers: true)
# File.open("public/inventory_restricted_brands.csv", 'w') {|file| file.write(arr.to_json)}



task run_brand_stats_script: [:environment] do
  arr = JSON.parse(UserBrand.where(marketplace: 'walmart', inventory_restricted: true).joins(:brand).distinct.select("restricted_reason, name").to_json).each{|row| row.delete('id')}
  system_brands = arr.map{|row| row['name']}

  arr = []
  User.active.each_with_index do |user, index|
    puts "email: #{user.email} -- index: #{index}"
    Apartment::Tenant.switch(user.tenant_name) do
      ids = Account.walmart.enabled.valid.active.ids
      c = 0
      AccountsProduct.uploaded.where(account_id: ids).where.not(brand: [nil, '']).in_batches(of: 1000) do |listings_batch|
        c += listings_batch.where("brand IN (?)", system_brands).count
        # puts "listings_might_retire: #{c}"
      end
      total_active_listings = AccountsProduct.uploaded.where(account_id: ids).count
      total_active_listings_with_brands = AccountsProduct.uploaded.where(account_id: ids).where.not(brand: [nil, '']).count
      if c.positive?
        hash = {email: user.email, total_active_listings: total_active_listings, total_active_listings_with_brands: total_active_listings_with_brands, active_listings_might_retire: c}
        puts hash
        arr << hash
      end
    end
    puts "arr count: #{arr.count}"
  end
  File.open("public/listings_might_retire_with_inventory_restricted_brands.json", 'w') {|file| file.write(arr.to_json)}
end

user = User.find_by(email: "alexandradirect@heonboard.com")
user.switch!

arr1 = JSON.parse(File.read("/Users/apple/Downloads/listings_might_retire_with_inventory_restricted_brands.json"))
arr1.sort_by{|a| a['active_listings_might_retire']}.reverse

pp arr1.select{|a| a['active_listings_might_retire'].positive?}


File.open("public/listings_might_retire_with_inventory_restricted_brands.json", 'w') {|file| file.write(arr1.to_json)}