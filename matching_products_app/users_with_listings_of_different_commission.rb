arr = []
User.active.each do |user|
  Apartment::Tenant.switch(user.tenant_name) do
    account = Account.walmart.enabled.valid.first
    next unless account
    created_at = account.walmart_report_requests.item.processed.last&.created_at
    next if created_at.blank? || created_at < 1.week.ago
    c =  account.accounts_products.where("commission > 0 AND commission != 15").count
    arr << {email: user.email, account_id: account.id, c: c } if c.positive?
  end
end
