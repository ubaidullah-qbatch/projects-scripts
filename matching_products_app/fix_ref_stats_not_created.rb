## final script
User.active.each do |user|
  Apartment::Tenant.switch(user.tenant_name) do
    (7.days.ago.to_date..Date.today).each do |date|
      # date = '2022-04-21'.to_date
      Account.refreshable.each do |account|
        # account = Account.find(4)
        next if account.created_at > date

        h = RefresherStat.where(account_id: account.id).where("created_at > ? AND created_at < ?", date.beginning_of_day.utc, date.end_of_day.utc).group("HOUR(created_at)").count
        # pp h
        arr = date == Date.today ? (0...Time.now.hour).to_a : (0...24).to_a
        missing_hours = arr - h.keys
        puts "Account: #{account.id} -- Date: #{date} -- #{missing_hours}" if missing_hours.count.positive?
        missing_hours.each do |m_hour|
          # m_hour = missing_hours.first
          m_time = Time.new(date.year, date.month, date.day, m_hour, 1, 0)
          # check if entry not already present?
          if RefresherStat.where(account_id: account.id).where("created_at > ? AND created_at < ?", (m_time).beginning_of_hour.utc, (m_time).end_of_hour.utc).empty?
            ## duplicate it
            previous_hour_entry = RefresherStat.where(account_id: account.id).where("created_at > ? AND created_at < ?", (m_time - 1.hour).beginning_of_hour, (m_time - 1.hour).end_of_hour).last
            if previous_hour_entry.present?
              dup_rs = previous_hour_entry.dup
              dup_rs.created_at = m_time
              dup_rs.updated_at = m_time
              pp dup_rs
              dup_rs.save!
            end
          end
        end
      end
    end;nil
  end;nil
end;nil






















