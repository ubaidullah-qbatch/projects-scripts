Dir['public/walmart_reports/item/*/*/*'].each do |name|
  if `du -sh #{name}`.include?('M')
    puts "#{name} -> " + `du -sh #{name}`
    puts "\n"
  end
end;nil

## Remove Old public/inventory_files/amazon files
Dir['public/inventory_files/amazon/*/*/*'].each_with_index do |path, index|
  timestamp = path.split('/').last.split('.').first.split('-').first
   if timestamp.to_datetime < 1.day.ago
    `rm #{path}`
    puts "removed file #{path} -- #{index}"
  end
end;nil



#SECONDARY
/home/ubuntu/apps/matching_products_app/public -> 3.9G

/home/ubuntu/apps/matching_products_app/wm_files_in_chunk_1000 -> 3.0G

/home/ubuntu/apps/matching_products_app/wm_files_in_chunk_1000_2 -> 5.0G

/home/ubuntu/apps/matching_products_app/1st-dec-2021-matt-dump.sql -> 11G

# /home/ubuntu/apps/matching_products_app/log -> 37G 

# /home/ubuntu/apps/matching_products_app/9-june-2021-matt-dump.sql -> 4.4G

/home/ubuntu/apps/matching_products_app/accounts_matches_5_jan_21.sql -> 6.3G

/home/ubuntu/apps/matching_products_app/'wm_files_in_chunk_1000_2' -> 5.0G




#PRIMARY
/home/ubuntu/apps/matching_products_app/public -> 29G /home/ubuntu/apps/matching_products_app/public

/home/ubuntu/apps/matching_products_app/Gemfile -> 4.0K /home/ubuntu/apps/matching_products_app/Gemfile

/home/ubuntu/apps/matching_products_app/zik8Tfwk -> 43G /home/ubuntu/apps/matching_products_app/zik8Tfwk

/home/ubuntu/apps/matching_products_app/all_other_tables.sql -> 1.7G  /home/ubuntu/apps/matching_products_app/all_other_tables.sql

/home/ubuntu/apps/matching_products_app/log -> 1.6G /home/ubuntu/apps/matching_products_app/log