# ===================================================================
User.find(3).switch!
last_id = 584982227
arr = JSON.parse(AccountsProduct.where("account_id = ? AND accounts_products.id >= ?", 23, last_id).joins(:suppliers).where("name = ?", 'amazon').select("item_id, url, sku").to_json)
arr.map{|a| a.merge!('asin' => Supplier.asin_from_url(a['url']).to_s.upcase) if a['url'].present?};nil
asins = arr.map{|a| a['asin']}.compact.uniq
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
  sku = arr.find{|a| a['url'].downcase.include?(asin.downcase)}.dig('sku')
  data << { packageWeight: packageWeight, sku: sku}
end;nil

listable = data.select{|d| d[:packageWeight] > 0 && d[:packageWeight] <= 1};nil
puts "listable count: #{listable.count}"
# data.select{|d| d[:packageWeight] == 0}.count
grouped_data = listable.group_by{|l| l[:packageWeight]}
grouped_data.keys.each_with_index do |weight, index|
  puts index
  next if weight <= 0
  
  skus = grouped_data[weight].map{|a| a[:sku] }
  AccountsProduct.where(account_id: 23).where("accounts_products.id >= ?", last_id).where("weight IS NULL OR weight = 0").where(sku: skus).joins(:suppliers).where("is_default = ? AND name = ?", true, 'amazon').update_all(weight_unit: "POUND", weight: weight)
end

AccountsProduct.where(account_id: 23).where("accounts_products.id >= ?", last_id).where("weight IS NULL OR weight = 0").count
AccountsProduct.where(account_id: 23).where("accounts_products.id >= ?", last_id).where("weight IS NOT NULL AND weight > ?", 0).group(:listing_status).count
AccountsProduct.where(account_id: 23).where("accounts_products.id >= ?", last_id).joins(:suppliers).group(:ship_to_warehouse).count
@feeds = Feed.where(id: [378891, 378890, 378887, 378888, 378889])

item_ids = data.select{|a| a[:packageWeight] == 0}.map{|a| a[:item_id]}
AccountsProduct.where(account_id: 23).where("accounts_products.id >= ?", 578005008).where(item_id: item_ids).joins(:suppliers).pluck(:url)
JSON.parse(File.read("public/keepa_response/B017LTAVK6"))["asin"]
JSON.parse(File.read("public/keepa_response/B017LTAVK6"))["packageWeight"]
## generate csv for all data you need to copy to other account & bulk import csv file
listable.map{|a|}
[18,27].each do |account_id|

  listable.in_groups_of(1000, false).each_with_index do ||
end



# =====================================================================================================
# scp /Users/apple/Downloads/matches_from_krw.json ubuntu@3.129.255.180:/home/ubuntu/apps/matching_products_app/public/
# rm -rf keepa_response
User.find(3).switch!
account = Account.find_by(id: 23)
# AccountsProduct.where(account_id: 23).where("created_at > ?", 1.hour.ago)
urls = Supplier.amazon.default_suppliers.joins(:accounts_product).where("accounts_products.created_at > ? AND account_id = ?", 1.hour.ago, account.id).pluck(:url)
# arr = JSON.parse File.read 'public/matches_from_krw_not_in_vwm.json'
# asins = arr.map{|a| a['asin'].upcase}.compact.uniq
asins = urls.map{|a| Supplier.asin_from_url(a)}.compact.uniq
file_dir = Rails.root.to_s + "/public/keepa_response"
FileUtils::mkdir_p file_dir unless File.directory?(file_dir)
asins.in_groups_of(99).each_with_index do |asins_batch, index|
  begin
    puts "iteration: #{index}"
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

## check asins count in folder
`pwd`
# `ls | wc -l`
# HTTParty.get("https://api.keepa.com/token?key=#{ENV['KEEPA_API_KEY']}")


# ===================================================================
## zappos
urls = Supplier.zappos.default_suppliers.joins(:accounts_product).where("listing_status = ? AND account_id = ?", 2, account.id).pluck(:url)

# arr = JSON.parse File.read 'public/zappos_file.json'
arr = JSON.parse File.read 'public/matches_from_krw_not_in_vwm.json'
arr = arr.map{|row| {sku: row['sku'], asin: Supplier.asin_from_url(row['url'])}};nil
arr.map!(&:stringify_keys);nil
asins = arr.map{|a| a['asin']}.compact.uniq.map(&:upcase)
file_dir = Rails.root.to_s +  "/public/keepa_response"
FileUtils::mkdir_p file_dir unless File.directory?(file_dir)
asins.in_groups_of(99).each_with_index do |asins_batch, index|
  begin
    puts "iteration: #{index}"
    full_url = "https://api.keepa.com/product?key=#{ENV['KEEPA_API_KEY']}&domain=1"
    full_url += "&asin=#{asins_batch.to_csv}"

    response = HTTParty.get(full_url)
    keepa_products = response["products"] || []
    keepa_products.each do |keepa_product|
      skus = arr.select{|a| a['asin'].to_s.downcase == keepa_product['asin'].to_s.downcase}.map{|a| a['sku']}.compact.uniq
      skus.each{|sku| File.open("#{file_dir}/#{sku}:#{keepa_product['asin']}", 'w') { |f| f.write keepa_product.to_json } }
    end;nil
    sleep(response["refillIn"].to_i/1000.to_f) unless response["tokensLeft"].to_i > 99
  rescue => e
    puts "#{index}------------#{e.message}"
  end
end



# ===================================================================
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
# asins = not_in_vwm_arr1.map{|a| a['asin']}.compact.uniq
