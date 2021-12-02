users = []
User.active.each do |user|
  Apartment::Tenant.switch(user.tenant_name) do
    accounts = Account.walmart.enabled.valid.where(vacation_mode: false)
    accounts.each do |account|
      hours_of_feeds = account.feeds.stock_update.where('created_at > ?', 1.days.ago).select("HOUR(created_at) as hour").map{|a|a["hour"]}.uniq
      if hours_of_feeds.count  < 24
        puts"**************#{{ email: user.email, account: account.id, hours_of_feeds: hours_of_feeds.count }}**************"
        users << { email: user.email, account: account.id, hours_of_feeds: hours_of_feeds.count }
      end
    end
  end
end;nil


email = "ollie3030@yahoo.com"
user = User.find_by(email: email)
user.switch!
account = Account.find(1)
account.accounts_products.uploaded.joins(:suppliers).where("is_default = ?", true).group("name").count
account.accounts_products.uploaded.where(is_mismatch: [false, nil], disable_feeds: false).where('auto_ordering_enabled = ? OR first_order_received = ?', true, false).joins(:suppliers).where("suppliers.is_default = ? AND #{ User.seller_fulfilled }", true).count


users.each do |row|
  user = User.find_by(email: row[:email])
  Apartment::Tenant.switch(user.tenant_name) do

    puts "#{user.email}***********#{Account.find(row[:account]).id}***********#{Account.find(row[:account]).vacation_mode}******#{Account.find(row[:account]).accounts_products.uploaded.joins(:suppliers).where("suppliers.platform_id IN (?) AND is_default = ?", Platform.refreshable_platforms.ids, true).count}"
  end
end
