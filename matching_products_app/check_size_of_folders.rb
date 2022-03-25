Dir['/home/ubuntu/apps/matching_products_app/*'].each do |name|
  if `du -sh #{name}`.include?('G')
    puts "#{name} -> " + `du -sh #{name}`
    puts "\n"
  end
end;nil
