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

task run_brand_stats_script: [:environment] do
  User.find(3).switch!
  system_brands = PlatformBrand.where(source: :system, platform_id: Platform.find_by(name: 'walmart').id).joins(:brand).pluck(:name).uniq

  arr = []
  User.active.where.not(id: 3).each_with_index do |user, index|
    Apartment::Tenant.switch(user.tenant_name) do
      ids = Account.walmart.enabled.valid.active.ids
      c = 0
      AccountsProduct.uploaded.where(account_id: ids).where.not(brand: [nil, '']).in_batches(of: 1000) do |listings_batch|
        c += listings_batch.where("brand IN (?)", system_brands).count
        # puts "listings_might_retire: #{c}"
      end
      hash = {email: user.email, total_active_listings: AccountsProduct.uploaded.where(account_id: ids).count, total_active_listings_with_brands: AccountsProduct.uploaded.where(account_id: ids).where.not(brand: [nil, '']).count, active_listings_might_retire: c}
      puts hash
      arr << hash
    end
  end
  File.open("public/listings_might_retire.json", 'w') {|file| file.write(arr.to_json)}
end

user = User.find_by(email: "alexandradirect@heonboard.com")
user.switch!

arr1 = JSON.parse(File.read("public/listings_might_retire.json"))

pp arr1.select{|a| a['active_listings_might_retire'].positive?}