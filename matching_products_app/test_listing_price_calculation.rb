## test listed price calculation


setting = s.platform.setting
account_setting = s.accounts_product.account
commission = s.accounts_product.commission.to_f.zero? ? 15 : s.accounts_product.commission
fix_profit = account_setting.fix_profit.to_f.zero? ? 6.0 : account_setting.fix_profit
profit_percentage = account_setting.profit_percentage.to_f.zero? ? 10.0 : account_setting.profit_percentage

tax_value = 1 + (setting&.tax.to_f/100.to_f)
price_with_multiplier = s.price.to_f * ([s.quantity_multiplier.to_i, 1].max)
shipping_fee = s.shipping_fee
unless setting&.has_prime_acc
  if price_with_multiplier < 25.0 && shipping_fee.to_f.zero?
    shipping_fee = setting&.non_prime_shipping.to_f
  end
end

total_price_plus_shipping_new = price_with_multiplier + shipping_fee.to_f

## fixed profit
price_by_fix_profit = (((total_price_plus_shipping_new * tax_value) + fix_profit.to_f) / (1 - commission.to_f * 0.01)).round(2)

## percentage profit
price_by_profit_percentage = (((total_price_plus_shipping_new * tax_value) * (1 + (profit_percentage * 0.01))) / (1 - commission.to_f * 0.01)).round(2)

## choose max
[price_by_fix_profit, price_by_profit_percentage].max