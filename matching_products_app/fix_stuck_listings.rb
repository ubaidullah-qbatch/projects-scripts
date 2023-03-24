# Fetch and import the missing price of listings with amazon suppliers via FetchAmazonProductsViaSpApi

def trigger
  user = User.find_by(email: 'amendablack86676@gmail.com')
  user.switch!
  Account.enabled.valid.ids
  account = Account.enabled.valid.last
  FetchAmazonSupplierPriceService.new(account).start
end

class FetchAmazonSupplierPriceService
  def initialize(account)
    @account = account
    # @listings_klass, @suppliers_klass = Platform.listings_klass_and_supplier(@account.marketplace)
    # @listings_table_name = @listings_klass.constantize.table_name
    # @suppliers_table_name = @suppliers_klass.constantize.table_name
  end

  def start
    missing_data_listings = AccountsProduct.where(listing_status: [:pending_upload, :added], account_id: @account.id).joins(:suppliers).where("is_default = ? AND name = ?", true, 'amazon').where("price IS NULL OR price = ? OR brand IS NULL OR brand = ?", 0, '')
    # missing_data_listings = AccountsProduct.where(account_id: @account.id).errored.price_not_present.joins(:suppliers).where(suppliers: { is_default: true, name: 'amazon' })
    fetch_and_import_prices(missing_data_listings)
  end
  
  def fetch_and_import_prices(missing_data_listings)
    @total_prices_found = 0
    puts "#########  Total Listings: #{missing_data_listings.length}  #########"
    missing_data_listings.select('accounts_products.id, suppliers.id as supplier_id, suppliers.url, item_id as asin').find_in_batches.with_index do |listings_batch, index|
      asins = get_suppliers_asins(listings_batch)
  
      puts '=' * 200
      # puts "Tenant: #{Apartment::Tenant.current}"
      puts "Batch Index: #{index}"
      prices_data = []
      asins.in_groups_of(1000, false).each do |asins_batch|
        products_arr = FetchAmazonProductsViaSpApiV1.new(asins_batch).start
        products_arr.each do |prod|
          puts "----- Price: #{prod[:price]}"
          puts "----- Brand: #{prod[:brand]}"
          listing_rows = listings_batch.select { |listing| listing['asin'] == prod[:marketplace_id] }
          next unless listing_rows.present? && prod[:message] != 'Could not fetch data due to no credentials available.'# && prod[:price].to_f.positive?
  
          listing_rows.each do |listing_row|
            prices_data << {
              listing_id: listing_row['id'], supplier_id: listing_row['supplier_id'], item_id: prod[:marketplace_id], price: prod[:price], brand: prod[:brand]
            }
          end;nil
        end
      end;nil
      next unless prices_data.present?
  
      @total_prices_found += prices_data.length
      update_listings_prices(prices_data)
      update_listings_brands(prices_data)
    end
  rescue => e
    puts '*' * 150
    puts e.message
    # ApplicationMailer.error_mail(
    #   { tenant_name: Apartment::Tenant.current, account_id: @account.id, error: e.message, backtrace: e.backtrace },
    #   'Fetch Amazon Weights And Dimensions Error'
    # ).deliver_now
  end

  private

  def update_listings_brands(prices_data)
    return unless prices_data.present?

    brands_grouped_data = prices_data.group_by { |data| data[:brand] }
    brands_grouped_data.except(nil).each do |brand, listings|
      AccountsProduct.where(account_id: @account.id, id: listings.map { |l| l[:listing_id] })
                     .joins(:suppliers).where(suppliers: { is_default: true, name: 'amazon' })
                     .where("price IS NULL OR price = ? OR brand IS NULL OR brand = ?", 0, '')
                     .update_all({ brand: brand })
    end;nil
  end

  def update_listings_prices(prices_data)
    return unless prices_data.present?

    prices_grouped_data = prices_data.group_by { |data| data[:price] }
    prices_grouped_data.except(nil, 0.0).each do |price, listings|
      Supplier.where(id: listings.map { |l| l[:supplier_id] }).update_all(price: price)
    end;nil
  end

e

  def get_suppliers_asins(listings_batch)
    listings_batch.map do |listing|
      asin = Supplier.asin_from_url(listing['url'])
      listing['asin'] = asin
      asin.to_s.upcase
    end.compact.uniq
  end
end