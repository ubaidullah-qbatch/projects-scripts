## Help Script for Repricer Team. This script will iterate on emails with provided marketplace_parnter_id & return stats

arr = [{id: '10001110438', email: 'tsquared@heonboard.com'}, {id: '10001115089', email: 'ljrn@heonboard.com'}, {id: '10001110588', email: 'infinityglobal@heonboard.com'}, {id: '10001116169', email: 'mrcsupplies@heonboard.com'}]

stats = []
arr.each do |row, index|
  user = User.find_by(email: row[:email])
  Apartment::Tenant.switch(user.tenant_name) do
    account = Account.where(marketplace_partner_id: row[:id]).last
    if account.platform.name == 'amazon'
      listings_group_by_name = account.amazon_listings.uploaded.joins(:amazon_suppliers).where("is_default = ?", true).group("name").count
    else
      listings_group_by_name = account.accounts_products.uploaded.joins(:suppliers).where("is_default = ?", true).group("name").count
    end
    stats << {email: user.email, user_is_active: user.is_active, repricer_type: account.repricer_type, account_is_valid: account.is_valid, account_is_enabled: account.enabled, listings_group_by_name: listings_group_by_name}
  end
end