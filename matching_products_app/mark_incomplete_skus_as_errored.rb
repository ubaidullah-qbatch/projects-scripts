################## Methods ##################

def unique_csv_by_sku(dir_path, file_name)
  csv = CSV.parse(File.read("#{dir_path}/#{file_name}.csv"), headers: true)
  csv.uniq{|a| a['seller-sku']}
end

def pick_latest_reports(all_reports)
  arr = []
  arr << all_reports.select{|a| a[:report_type] == '_GET_MERCHANT_LISTINGS_ALL_DATA_' }.sort_by{|a| a[:updated_at] }.last
  arr << all_reports.select{|a| a[:report_type] == '_GET_MERCHANT_LISTINGS_DATA_' }.sort_by{|a| a[:updated_at] }.last
  arr.compact
end

def merge_reports(all_reports)
  # merge & unique records in final file.
  dir_path = Rails.root.to_s + "/public/inventory_files/amazon/#{Apartment::Tenant.current}/#{@account.id}"
  file_name = "#{DateTime.now.strftime('%Y%m%d%H%M%S')}-inventory-report"
  FileUtils::mkdir_p dir_path unless File.directory?(dir_path)
  CSV.open("#{dir_path}/#{file_name}.csv", "wb") do |csv|
    all_reports.sort_by { |a| -a[:report_type].length }.each_with_index do |report_row, index|
      response = @report_client.get_report(report_row[:report_id]).parse
      csv << response.headers if index.zero?
      response.each do |row|
        record = index.zero? ? row.to_h : row.to_h.merge('status' => 'Active')
        csv << record.values
      end
    end
  end
  [dir_path, file_name]
end


################## SCRIPT ##################
report_types = ['_GET_MERCHANT_LISTINGS_ALL_DATA_', '_GET_MERCHANT_LISTINGS_DATA_']
User.active.each do |user|
  Apartment::Tenant.switch(user.tenant_name) do
    Account.amazon_with_keys.enabled.active.valid.each do |account|
      # account = Account.amazon_with_keys.enabled.active.valid.first
      @account = account;nil
      @client = @account.set_client_for_feed
      @report_client = @account.set_client_for_report
      all_reports = []
      @account.mws_report_requests.where(report_type: report_types, report_status: :processed).last(2).each do |report|
        all_reports << {report_type: report.report_type, report_id: report.report_id, updated_at: report.updated_at}
      end
      if all_reports.map{|a| a[:report_type]}.compact.uniq.count > 1
        all_reports = pick_latest_reports(all_reports)
        dir_path, file_name = merge_reports(all_reports)
        csv = unique_csv_by_sku(dir_path, file_name)
        incomplete_skus = csv.map{|a| a['seller-sku'] if a['status'] == 'Incomplete'}.compact
        puts "#{user.email} -- #{@account.id} --- #{csv.map{|a| a['status'] }.compact.tally} -- #{@account.amazon_listings.where(sku: incomplete_skus).uploaded.count}"
        incomplete_skus.in_groups_of(1000, false).each_with_index do |skus_batch, index|
          listings = @account.amazon_listings.uploaded.where(sku: skus_batch)
          listings.update_all(listing_status: :errored) if listings.present?
        end
      end
    end
  end
end