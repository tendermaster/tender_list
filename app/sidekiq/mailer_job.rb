class MailerJob
  include Sidekiq::Job

  def perform(*args)

    # sleep 2
    p "running mailer #{Time.zone.now}"

    # TODO: change freq
    Query.all.each do |query|
      p query
      if query&.last_sent.present? &&
        query&.updates.present? &&
        Time.zone.now > query&.last_sent

        days_from_last_sent = (Time.zone.now - query.last_sent) / 1.day
        updates = query.updates

        p "current stats query_id: #{query.id}, days_from_last_sent: #{days_from_last_sent}, updates: #{updates}"

        if (updates == 'REGULARLY' && days_from_last_sent >= 3) ||
          (updates == 'WEEKLY' && days_from_last_sent >= 7) ||
          (updates == 'MONTHLY' && days_from_last_sent >= 30)
          # ensure results are present
          query_string = QueriesController.get_query_string(query)

          # Count new tenders since last_sent using BM25
          tender_count = TenderSearch.count_matching(query_string, since: query.last_sent)

          # Count total open tenders using BM25
          total_tender_count = TenderSearch.count_matching(query_string)

          p "tender count: #{tender_count}, total: #{total_tender_count}, after: #{query.last_sent.utc}, search_term: #{query_string}"
          if tender_count > 0
            email = query.user.email
            puts "Sending Email to: #{email}"
            NotificationMailer.with(email: email,
                                   tender_count: tender_count,
                                   total_tender_count: total_tender_count,
                                   query_id: query.id,
                                   query_name: query.name
            ).send_tender_updates.deliver_later
            query.update(last_sent: Time.zone.now)
          end
        else
          p 'No email sent'
        end
      else
        p 'missing data'
      end
    end
  end
end

# Sidekiq::Cron::Job.create(name: 'MailerJob - every 12 hour', cron: '0 */12 * * *', class: 'MailerJob') # execute at every 12 hour

# every hour
# Sidekiq::Cron::Job.create(name: 'MailerJob - every 12 hour', cron: '0 * * * *', class: 'MailerJob')
#
