all_amz_arr = []
all_wm_arr = []
User.active.each do |user|
  Apartment::Tenant.switch(user.tenant_name) do
    amz_ids, wm_ids = [], []

    amazon_listing_ids = AmazonListing.uploaded.left_outer_joins(:amazon_suppliers).where("is_default = ?", false).ids.uniq
    amazon_listing_ids.in_groups_of(5000, false).each_with_index do |ids_batch, index|
      amazon_listing_arr = AmazonSupplier.where(amazon_listing_id: ids_batch).pluck(:amazon_listing_id, :is_default)
      amazon_listing_arr.uniq!;nil
      ids_with_no_default_supplier_for_amazon = get_no_default_supplier_ids(amazon_listing_arr)
      amz_ids += ids_with_no_default_supplier_for_amazon if ids_with_no_default_supplier_for_amazon.present?
      # assign_default_suppliers(ids_with_no_default_supplier_for_amazon, 'AmazonSupplier', 'amazon_listing_id')
    end
    all_amz_arr << {email: user.email, ids_for_amz: amz_ids} if amz_ids.present?

    walmart_listing_ids = AccountsProduct.uploaded.left_outer_joins(:suppliers).where("is_default = ?", false).ids.uniq
    amazon_listing_ids.in_groups_of(5000, false).each_with_index do |ids_batch, index|
      walmart_listing_arr = Supplier.where(accounts_product_id: ids_batch).pluck(:accounts_product_id, :is_default)
      walmart_listing_arr.uniq!;nil
      ids_with_no_default_supplier_for_walmart = get_no_default_supplier_ids(walmart_listing_arr)
      wm_ids += ids_with_no_default_supplier_for_walmart if ids_with_no_default_supplier_for_walmart.present?
      # assign_default_suppliers(ids_with_no_default_supplier_for_walmart, 'Supplier', 'accounts_product_id')
    end
    all_wm_arr << {email: user.email, ids_for_wm: wm_ids} if wm_ids.present?
  end
end;nil


def get_no_default_supplier_ids(arr)
  arr1 = []
  arr.each do |a|
    listing_suppliers_arr = arr.select{|aa| aa[0] == a[0]}
    arr_default_values = listing_suppliers_arr.map{|aa1| aa1[1]}.uniq
    arr1 << a if listing_suppliers_arr.count == 1 && !arr_default_values.first
  end;nil
  ids_with_no_default_supplier = arr1.map{|a| a[0]}.compact.uniq
  ids_with_no_default_supplier
end

def assign_default_suppliers(ids_with_no_default_supplier, supplier_table_name, listing_column_id)
  return if ids_with_no_default_supplier.blank?

  refreshable_platforms_ids = Platform.refreshable_platforms.ids
  unknown_platform = Platform.find_by(name: 'unknown')
  ids_with_no_default_supplier.each do |id|
    ## if refreshable_platforms_ids present -> mark that as default
    refreshable_sup = supplier_table_name.constantize.where("#{listing_column_id}" => id).where(platform_id: refreshable_platforms_ids, is_default: false).first
    (refreshable_sup&.update_columns(is_default: true);next) if refreshable_sup
    ## else mark unknown as default
    unknown_supplier = supplier_table_name.constantize.where("#{listing_column_id}" => id).where(platform_id: unknown_platform.id).first
    (unknown_supplier.update_columns(is_default: true);next) if unknown_supplier.present?
    supplier_table_name.constantize.create(platform_id: unknown_platform.id, is_default: true, url: "unknown_#{Time.now.to_i}_hy")
  end
end

# pp AmazonSupplier.where(amazon_listing_id: ids_with_no_default_supplier_for_amazon).pluck(:amazon_listing_id, :is_default)
# pp Supplier.where(accounts_product_id: ids_with_no_default_supplier_for_walmart).pluck(:accounts_product_id, :is_default)