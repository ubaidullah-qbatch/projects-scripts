def run_ecs_task(data)
  task_variables = data.map{ |k, v| { name: k.to_s, value: v.to_s } }
  subnets = ["subnet-e3337b99", "subnet-f471c1b8", "subnet-b3aebddb"]
  response = @ecs_client.run_task({
    cluster: "matching-app-services",
    task_definition: "matching-app-services",
    count: 1,
    platform_version: "1.4.0",
    capacity_provider_strategy: [{ capacity_provider: "FARGATE_SPOT" }],
    network_configuration: { awsvpc_configuration: { subnets: subnets, assign_public_ip: "ENABLED" } },
    overrides: { container_overrides: [{ name: "matching_app_services", environment: task_variables }] }
  })
  (response[:tasks][0][:containers][0][:container_arn]).split('/')[2]
end

def ecs_task_status(task_id)
  response = @ecs_client.describe_tasks(cluster: 'matching-app-services', tasks: [task_id])
  task = response.to_h[:tasks]&.first
  { status: task&.dig(:last_status), stopped_reason: task&.dig(:stopped_reason) }
end

arr = []
emails = ["wnewporti@yahoo.com", "mcialicantellc@gmail.com", "admin@amazinggoods.biz", "onlineocean14@gmail.com", "coon.jordan@gmail.com", "regeeni.ec@oneupecommerce.com"]
User.active.where(email: emails).each do |user|
  Apartment::Tenant.switch(user.tenant_name) do
    CsvFile.bulk_listing.errored.where("created_at > ?", 7.days.ago.beginning_of_day).each do |csv_file|
      @account = csv_file.account
      @listing_platform_id = @account.platform.id
      @listing_platform_name = @account.platform.name
      @listings_klass = (@listing_platform_name == 'walmart' ? 'AccountsProduct' : 'AmazonListing')
      @suppliers_klass = (@listing_platform_name == 'walmart' ? 'Supplier' : 'AmazonSupplier')
      @current_user = User.find_by(tenant_name: Apartment::Tenant.current)
      @ecs_client = Aws::ECS::Client.new

      data = {
        CSV_FILE_ID: csv_file.id,
        TENANT_EMAIL: @current_user.email,
        S3_URL: csv_file.s3_url
      } if csv_file.s3_url.present?
      task_id = run_ecs_task(data) if csv_file.s3_url.present?
      csv_file.update_columns(ecs_task_id: task_id, status: :pending, retries_count: 0)
    end
    # c = CsvFile.bulk_listing.errored.where("created_at > ?", 7.days.ago.beginning_of_day).count
    # arr << {email: user.email, c: c} if c.positive?
  end
end;nil