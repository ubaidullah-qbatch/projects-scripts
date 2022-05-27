


task run_brand_import_script: [:environment] do

nohup bundle exec rake amazon_apis:run_brand_import_script --trace > rake.out 2>&1 &

tail -f rake.out
cat rake.out
: > rake.out


pid = 32263
pid = 668
pid = 1339

ps aux | grep run_brand_import_script
ps aux | grep 32263
ps aux | grep 668
ps aux | grep 1339



## Methods ##
def create_brands(arr)
  Brand.where(name: arr.map{|b| b[:name]}).count
  brands = arr.map{|b| [b[:name]]}
  Brand.import [:name], brands, on_duplicate_key_ignore: true
end

def create_platform_brands(arr)
  platform = Platform.find_by(name: 'amazon')
  brands_arr = JSON.parse(Brand.where(name: arr.map{|b| b[:name]}).select("id as brand_id, name").to_json, symbolize_names: true)
  brands_arr.each do |row|
    reason = @csv.find{|a| a["Brand"]&.strip&.downcase == row[:name]&.strip&.downcase}&.dig('Reason')
    row.merge!(platform_id: platform.id, restricted_reason: reason, blacklist: true, surety: 100, source: :system)
    row.delete(:id)
    row.delete(:name)
  end;nil
  columns = brands_arr.first.keys
  brands_arr.in_groups_of(200, false) do |records_batch|
    puts records_batch.count
    PlatformBrand.import columns, records_batch, on_duplicate_key_update: [:source, :surety, :blacklist, :updated_at]
  end
end

## Code ##

## Read File ##
path = "public/brands_from_getipalert.csv"
@csv = CSV.parse(File.read(path), headers: true)
arr = csv.map{|a| {name: a['Brand']&.strip&.downcase, reason: a['Reason']}}

## create in global db
Apartment::Tenant.switch(ENV['RDS_PRODUCTION_WRITING_DB_NAME']) do
  create_brands(arr)
  create_platform_brands(arr)
end

## create for all users
User.where("id > ?", 200).each_with_index do |user, index|
  puts "processing email: #{index} -- #{user.email}"
  Apartment::Tenant.switch(user.tenant_name) do
    create_brands(arr)
    create_platform_brands(arr)
  end
end;nil

## Import in UserBrand Global Table
# create_user_brands
def create_user_brands
  Apartment::Tenant.switch(ENV['RDS_PRODUCTION_WRITING_DB_NAME']) do
    create_brands(arr)
    brands_arr = JSON.parse(Brand.where(name: arr.map{|b| b[:name]}).select("id as brand_id, name").to_json, symbolize_names: true)
    brands_arr.each do |row|
      reason = @csv.find{|a| a["Brand"]&.strip&.downcase == row[:name]&.strip&.downcase}&.dig('Reason')
      ## against partner_id of KRA
      row.merge!(restricted_reason: reason, marketplace: 'amazon', user_id: 3, partner_id: 3, ipalert_restricted: true)
      row.delete(:id)
      row.delete(:name)
    end;nil
    columns = brands_arr.first.keys
    brands_arr.in_groups_of(2000, false) do |records_batch|
      UserBrand.import columns, records_batch, on_duplicate_key_update: [:updated_at]
    end
  end
end






## Rake Task ##
task run_brand_import_script: [:environment] do
  path = "public/brands_from_getipalert.csv"
  @csv = CSV.parse(File.read(path), headers: true)
  arr = @csv.map{|a| {name: a['Brand']&.strip&.downcase, reason: a['Reason']}}

  def create_brands(arr)
    Brand.where(name: arr.map{|b| b[:name]}).count
    brands = arr.map{|b| [b[:name]]}
    Brand.import [:name], brands, on_duplicate_key_ignore: true
  end

  def create_platform_brands(arr)
    platform = Platform.find_by(name: 'amazon')
    brands_arr = JSON.parse(Brand.where(name: arr.map{|b| b[:name]}).select("id as brand_id, name").to_json, symbolize_names: true)
    brands_arr.each do |row|
      reason = @csv.find{|a| a["Brand"]&.strip&.downcase == row[:name]&.strip&.downcase}&.dig('Reason')
      row.merge!(platform_id: platform.id, restricted_reason: reason, blacklist: true, surety: 100, source: :system)
      row.delete(:id)
      row.delete(:name)
    end;nil
    columns = brands_arr.first.keys
    brands_arr.in_groups_of(200, false) do |records_batch|
      puts records_batch.count
      PlatformBrand.import columns, records_batch, on_duplicate_key_update: [:source, :surety, :blacklist, :updated_at]
    end
  end

  ## create for all users
  User.where("id > ?", 200).each_with_index do |user, index|
    puts "processing email: #{index} -- #{user.email}"
    Apartment::Tenant.switch(user.tenant_name) do
      create_brands(arr)
      create_platform_brands(arr)
    end
  end;nil
end