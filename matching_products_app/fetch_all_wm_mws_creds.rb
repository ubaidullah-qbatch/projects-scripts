## amazon creds
amz_arr = []
User.active.each do |user|
  Apartment::Tenant.switch(user.tenant_name) do
    mws_keys = Account.amazon.enabled.valid.amazon_with_keys.pluck(:mws_keys)
    amz_arr << mws_keys if mws_keys.present?
  end
end


## walmart creds
wm_arr = []
User.active.each do |user|
  Apartment::Tenant.switch(user.tenant_name) do
    wm_keys = Account.walmart.enabled.valid.pluck(:consumer_id, :private_key)
    wm_arr << wm_keys if wm_keys.present?
  end
end