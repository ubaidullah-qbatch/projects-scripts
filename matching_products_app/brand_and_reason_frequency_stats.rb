Stats of restricted brands with their reasons & frequency
Brand, users count that got this brand restriction, restricted_reasons frequency

brands_restricted_for_multiple_users = UserBrand.where(marketplace: 'walmart').joins(:brand).select(:brand_id).group(:brand_id).having("count(*) > 1").count
arr = []
brands_restricted_for_multiple_users.each do |brand_id, brand_count|
  user_brands_arr = UserBrand.where(marketplace: 'walmart').where(brand_id: brand_id).select(:restricted_reason, :inventory_restricted, :scrape_restricted, :manually_restricted, :ipalert_restricted, :email_restricted).as_json
  ## group sources
  sources_hash = {}
  user_brands_arr.each do |row|
    if row['inventory_restricted']
      sources_hash[:inventory_restricted] = 0 unless sources_hash[:inventory_restricted]
      sources_hash[:inventory_restricted] += 1 if row['inventory_restricted']
    end
    if row['manually_restricted']
      sources_hash[:manually_restricted] = 0 unless sources_hash[:manually_restricted]
      sources_hash[:manually_restricted] += 1 if row['manually_restricted']
    end
    if row['email_restricted']
      sources_hash[:email_restricted] = 0 unless sources_hash[:email_restricted]
      sources_hash[:email_restricted] += 1 if row['email_restricted']
    end
    if row['scrape_restricted']
      sources_hash[:scrape_restricted] = 0 unless sources_hash[:scrape_restricted]
      sources_hash[:scrape_restricted] += 1 if row['scrape_restricted']
    end
    if row['ipalert_restricted']
      sources_hash[:ipalert_restricted] = 0 unless sources_hash[:ipalert_restricted]
      sources_hash[:ipalert_restricted] += 1 if row['ipalert_restricted']
    end
  end
  restricted_reasons = user_brands_arr.map{|a| a['restricted_reason']}.compact.tally
  b = Brand.find_by(id: brand_id)
  arr << {name: b.name, brand_count: brand_count, sources: sources_hash, restricted_reasons: restricted_reasons.presence}
end;nil

pp arr

CSV.open("public/restricted_brands_frequency_across_users.csv", "w") do |csv|
  csv << arr.first.keys.map(&:to_s).map(&:humanize).map(&:upcase)
  arr.each do |r|
    csv << r.values
  end;nil
end;nil
csv = CSV.parse(File.read('public/restricted_brands_frequency_across_users.csv'), headers: true)