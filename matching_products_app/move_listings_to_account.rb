## List 5 Stuller Items to Roasted Sun

User.find(3).switch!
## MJJ
from_account = Account.find_by(partner_id: '16')
## ROASTED SUN
to_account = Account.find_by(partner_id: '14')
stuller = Platform.find_by(name: 'stuller')

Platform.wholesale.joins(suppliers: :accounts_product).where("listing_status = ? AND account_id = ?", 2, ).count

## check count
# to_account.accounts_products.added.joins(:suppliers).where("is_default = ? AND suppliers.platform_id = ?", true, stuller.id).count
# from_account.accounts_products.uploaded.joins(:suppliers).where("is_default = ? AND suppliers.platform_id = ?", true, stuller.id).count

from_account.accounts_products.uploaded.joins(:suppliers).where("is_default = ? AND suppliers.platform_id = ?", true, stuller.id).limit(5).each do |from_ap|
  ActiveRecord::Base.transaction do
    ## update accounts product 
    to_ap = from_ap.dup
    to_ap.sku = "M-#{to_ap.sku}-J"
    to_ap.listing_status = AccountsProduct.listing_statuses['added']
    to_ap.account_id = to_account.id
    to_ap.weight_unit = nil
    to_ap.weight = nil
    to_ap.save

    ## update supplier
    from_supplier = from_ap.default_supplier
    next unless from_supplier
    next unless to_ap
    to_supplier = from_supplier.dup
    to_supplier.accounts_product_id = to_ap.id
    to_supplier.save
  end
end

# AccountsProduct.where("created_at > ?", 1.hour.ago).destroy_all
# to_account.accounts_products.each{|ap| ap.suppliers.destroy_all}
# to_account.accounts_products.destroy_all


# =====================================
# Retire wholesale (topdawg with no orders) & list to roasted sun
User.find(3).switch!
## VWM
from_account = Account.find_by(id: 23)
## ROASTED SUN
to_account = Account.find_by(partner_id: '14')
platform = Platform.find_by(name: 'topdawg')
order_skus = ['SP-307764-26450267--85-26449982', 'SP-190764-26452049--60-26451759', 'SP-307764-26450262--85-26449977', 'SP-164764-26449049--84-26448753', 'SP-522764-26449643--76-26449369', 'SP-307764-26450706--85-26450414', 'SP-324764-26452887--79-26452690', 'SP-190764-26452643--60-26452353', 'SP-87-764-26452934-673-26452737', 'SP-291764-26452606--81-26452316', 'SP-138764-26451382--84-26451101', 'SP-375764-26450209--62-26449922', 'SP-375764-26451317--62-26451035', 'SP-313764-26452093--85-26451803', 'SP-108764-26451301--62-26451019', 'SP-324764-26451986--79-26451695', 'SP-top764-46517331-daw-46517039', 'SP-top764-48277496-daw-48277217', 'SP-216764-26448457--74-26448161', 'SP-top764-48279807-daw-48279508', 'SP-top764-46513905-daw-46513605', 'SP-top764-46515080-daw-46514828', 'SP-237764-26450758--60-26450466', 'SP-6-8764-26451992-515-26451701', 'SP-99-764-26451901-703-26451610', 'SP-221764-26450084--61-26449797', 'SP-top764-48279780-daw-48279481', 'SP-134764-26452563--74-26452273', 'SP-87-764-26452926-673-26452729', 'SP-top764-48278176-daw-48277884', 'SP-top764-46514910-daw-46514655', 'SP-top764-46522965-daw-46522787', 'SP-663764-26453039--87-26452842', 'SP-top764-46522969-daw-46522791', 'SP-727764-26452667--81-26452377', 'SP-top764-46513879-daw-46513579', 'SP-top764-48285779-daw-48285482', 'SP-727764-26453008--81-26452811']
## group by wholesalers
# Platform.wholesale.joins(suppliers: :accounts_product).where("listing_status = ? AND account_id = ?", 2, from_account.id).group(:name).count

## check count
# to_account.accounts_products.added.joins(:suppliers).where("is_default = ? AND suppliers.platform_id = ?", true, platform.id).count
# from_account.accounts_products.uploaded.joins(:suppliers).where("is_default = ? AND suppliers.platform_id = ?", true, platform.id).count #23410

from_account.accounts_products.uploaded.where.not(sku: order_skus).joins(:suppliers).where("is_default = ? AND suppliers.platform_id = ?", true, platform.id).each_with_index do |from_ap, index|
  puts "iteration: #{index}"
  ActiveRecord::Base.transaction do
    ## update accounts product 
    to_ap = from_ap.dup
    to_ap.account_id = to_account.id
    to_ap.sku = "V-#{to_ap.sku}-M"
    to_ap.listing_status = AccountsProduct.listing_statuses['added']
    to_ap.shipping_template_id = nil
    to_ap.price_changed = false
    to_ap.save

    ## update supplier
    from_supplier = from_ap.default_supplier
    next unless from_supplier
    next unless to_ap
    to_supplier = from_supplier.dup
    to_supplier.accounts_product_id = to_ap.id
    to_supplier.stock = 0
    to_supplier.save
  end
end

# AccountsProduct.where("created_at > ?", 1.hour.ago).destroy_all
# to_account.accounts_products.each{|ap| ap.suppliers.destroy_all}
# to_account.accounts_products.destroy_all