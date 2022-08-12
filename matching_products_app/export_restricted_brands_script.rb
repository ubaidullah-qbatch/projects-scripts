user = User.find 3
user.switch!

platform = Platform.find_by name: 'walmart'
wm_arr = platform.manual_restricted_brands.select(:name, :restricted_reason).as_json.map{|a| a.except('id')}

CSV.open("public/matt_wm_manual_restricted_brands.csv", "w") do |csv|
csv << ['Name', 'Restricted Reason']
wm_arr.each do |r|
  csv << r.values
end;nil
end;nil
csv = CSV.parse(File.read('public/matt_wm_manual_restricted_brands.csv'), headers: true)

# File.open("public/inventory_restricted_brands.csv", 'w') {|file| file.write(arr.to_json)}


user = User.find 3
user.switch!

platform = Platform.find_by name: 'amazon'
amz_arr = platform.manual_restricted_brands.select(:name, :restricted_reason).as_json.map{|a| a.except('id')}

CSV.open("public/matt_amz_manual_restricted_brands.csv", "w") do |csv|
csv << ['Name', 'Restricted Reason']
amz_arr.each do |r|
  csv << r.values
end;nil
end;nil
csv = CSV.parse(File.read('public/matt_amz_manual_restricted_brands.csv'), headers: true)


brands = Platform.find_by(name: 'walmart').brands.where("platform_brands.surety >= ? AND blacklist = ? AND source = ?", 75, true, PlatformBrand.sources['manual']).where("name IN (?)", b).pluck("brands.name")
skip = b - brands