## fix listed price 0
User.find(3).switch!

account = Account.find 31

ap_ids = account.accounts_products.uploaded.where(last_submitted_price: 0).ids
# .joins(:suppliers).group(:offer_status).count

ap_ids1 = Supplier.where(accounts_product_id: ap_ids).where(offer_status: :offer_found).where("price > 0").pluck(:accounts_product_id);nil
skus = account.accounts_products.uploaded.where(id: ap_ids1).pluck(:sku);nil

buybox_csv = CSV.parse(open(WalmartReportRequest.buybox.processed.where(account_id: 31).last.s3_url), headers: true)
item_csv = CSV.parse(File.read('/Users/apple/Downloads/ItemReport_10001081837_2022-04-22T160006.392000.csv'), headers: true)


found_arr = []
skus1.each_with_index do |sku, index|
  row = item_csv.find{|a| a['SKU'] == sku}
  found_arr << sku if item_csv.find{|a| a['SKU'] == sku}.present?
  puts "found count: #{found_arr.count}"
  break if found_arr.count > 10
end;nil


include WalmartApi
BATCH_SIZE = 1000
THREAD_COUNT = 50

User.find(3).switch!
@account = Account.find 31
@agent = Mechanize.new
@skus_array_semaphore = Mutex.new
@walmart_token_semaphore = Mutex.new
@skus_with_statuses, @api_failed_skus = [], []

skus = @account.accounts_products.uploaded.where(last_submitted_price: 0).pluck(:sku)

def fetch_all_skus(skus)
  return if skus.blank?

  puts "start time: #{Time.now}"
  skus_batch_size = [skus.size/THREAD_COUNT, 1].max
  threads = []
  skus.in_groups_of(skus_batch_size, false).each_with_index do |skus_batch, index|
    threads << Thread.new { fetch_skus_in_batches(skus_batch, index) }
  end;nil
  threads.each { |t| t.join }
  puts "end time: #{Time.now}"
end

def fetch_skus_in_batches(skus_batch, thread_index)
  puts "thread_no: #{thread_index} started"
  skus_batch.each_with_index do |sku, index|
    puts "#{sku} --- thread_index: #{thread_index} --- index: #{index}"
    response = get_an_item_via_threading(@agent, @account, sku)
    (@skus_array_semaphore.synchronize { @api_failed_skus << sku };next) unless response
    @skus_array_semaphore.synchronize { @skus_with_statuses << {sku: response['sku'], status: response['lifecycleStatus'], published_status: response['publishedStatus'], last_submitted_price: response.dig('price', 'amount').to_f} }
  end
  puts "thread_no: #{thread_index} finished"
  Thread.exit()
end

def get_an_item_via_threading(agent, account, sku)
  response, token = nil, nil
  @walmart_token_semaphore.synchronize{
    token = generate_token(agent, account)
  }
  headers = make_headers('application/json', account.keys, token)
  begin
    response = JSON.parse(agent.get(base_url + "items/#{URI.escape(sku)}", [], nil, headers)&.body)&.dig('ItemResponse')&.first
  rescue StandardError => e
    puts e.message
    if e.message.include?('404 => Net::HTTPNotFound')
      return { 'sku': sku, 'lifecycleStatus': 'NOT_FOUND', 'publishedStatus': nil }.with_indifferent_access
    end
  end
  response
end


fetch_all_skus(skus)
i = 0
@skus_with_statuses.group_by{|a| a[:last_submitted_price]}.each do |price, skus_batch|
  puts "index: #{i}"
  @account.accounts_products.where(sku: skus_batch.map{|a| a[:sku]}.compact.uniq).update_all(last_submitted_price: price)
  i += 1
end;nil


puts "left 0 price count: #{@account.accounts_products.uploaded.where(last_submitted_price: 0).count}"
# get_an_item(@agent, @account, 'SP-FfC2-125541792-Ev-125541526')



item_csv = CSV.parse(File.read('/Users/apple/Downloads/ItemReport_10001081837_2022-04-22T160006.392000.csv'), headers: true)
skus1 = @account.accounts_products.uploaded.where(last_submitted_price: 0).pluck(:sku)
# arr = item_csv.map{ |row| {sku: row['SKU'], price: row['Price'].to_f, bb_price: row['Buy Box Item Price']} if skus1.include?(row['SKU']) if row['Price'].to_f.positive? || row['Buy Box Item Price'].to_f.positive? }.compact.uniq
arr = item_csv.map{ |row| {sku: row['SKU'], price: row['Price'].to_f, bb_price: row['Buy Box Item Price']} if skus1.include?(row['SKU']) }.compact.uniq
i = 0
arr.group_by{|a| a[:price]}.each do |price, skus_batch|
  puts "index: #{i}"
  @account.accounts_products.where(sku: skus_batch.map{|a| a[:sku]}.compact.uniq).update_all(last_submitted_price: price)
  i += 1
end;nil




new_skus = @account.accounts_products.uploaded.where(last_submitted_price: 0).pluck(:sku) - skus
@account.walmart_report_requests.buybox.processed.last.s3_url

buybox_csv = CSV.parse(open('https://product-images-matching.s3.us-east-2.amazonaws.com/walmart_reports/1610355554/31/25627-buybox.csv'), headers: true)


# buybox_csv.find{|a| a['SKU'] == new_skus.first}
found_arr = []
new_skus.each_with_index do |sku, index|
  row = buybox_csv.find{|a| a['SKU'] == sku}
  found_arr << sku if row.present?
  puts "found count: #{found_arr.count}"
  break if found_arr.count > 10
end;nil













