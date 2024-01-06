class MailerJob
  include Sidekiq::Job

  def perform(*args)

    # sleep 2
    p "running mailer #{Time.zone.now}"

    Query.all.each do |query|
      p query
      if query&.last_sent.present? &&
        query&.updates.present? &&
        Time.zone.now > query&.last_sent

        days_from_last_sent = (Time.zone.now - query.last_sent) / 1.day
        updates = query.updates

        p "current stats query_id: #{query.id}, days_from_last_sent: #{days_from_last_sent}, updates: #{updates}"

        if (updates == 'WEEKLY' && days_from_last_sent >= 7) || (updates == 'MONTHLY' && days_from_last_sent >= 30)
          # ensure results are present
          query_string = QueriesController.get_query_string(query)

          tender_count = Tender.where([
                                        "tenders.tender_text_vector @@ websearch_to_tsquery('english', ?)
  and (submission_close_date > now())
  and (is_visible = true)
  and (created_at > ?)
",
                                        query_string,
                                        query.last_sent.utc
                                      ]).count
          p "tender count: #{tender_count}, after: #{query.last_sent.utc}, search_term: #{query_string}"
          if tender_count > 0
            email = query.user.email
            puts "Sending Email to: #{email}"
            ApplicationMailer.with(email: email,
                                   tender_count: tender_count,
                                   query_id: query.id,
                                   query_name: query.name
            ).send_tender_updates.deliver_later
            query.update(last_sent: Time.zone.now)
          end
        else
          p 'No email sent'
        end

      end

    end
  end
end

# Sidekiq::Cron::Job.create(name: 'MailerJob - every 12 hour', cron: '0 */12 * * *', class: 'MailerJob') # execute at every 12 hour

# every hour
# Sidekiq::Cron::Job.create(name: 'MailerJob - every 12 hour', cron: '0 * * * *', class: 'MailerJob')
#
