arr = []
Dir['log/supplier_api/*.log'].each do |file_path|
  response = `grep '500 => Net::HTTPInternalServerError' #{file_path}`.split("\n")
  arr += response
end;nil


arr.select { |str| str.include?('amazon.com') }.count
urls = arr.map { |str| str.split('supplier_response?data=').last.split('&response_type=detail_ha').first }.compact.uniq
urls.select{ |url| url.include?('walmart.com') }.count
CSV.open("public/internal_server_urls.csv", 'wb') do |csv|
  csv << ['URL']
  urls.each {|url| csv << [url]}
end;nil
csv = CSV.parse(File.read("public/internal_server_urls.csv"), headers: true)