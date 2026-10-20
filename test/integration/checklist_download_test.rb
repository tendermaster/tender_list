require 'test_helper'

class ChecklistDownloadTest < ActionDispatch::IntegrationTest
  def download(**params)
    post checklist_download_path, params: { fill_ms: 10_000, full_name: 'Asha Rao', email: 'lead@example.com',
                                            phone: '9876543210', report_type: 'construction' }.merge(params)
  end

  test 'emails the files when mail is on, and saves the request for the team' do
    assert_enqueued_emails(1) { download }
    assert_includes response.body, 'Please check your email'

    lead = Lead.sole
    assert_equal ['checklist_download', 'pending', '+919876543210'], [lead.topic, lead.status, lead.phone]
    assert_equal 'Constructions and Infrastructure Tenders', lead.answers['Checklist']
  end

  test 'shows the files on the page while mail is off' do
    ActionMailer::Base.perform_deliveries = false
    assert_no_enqueued_emails { download }
    assert_includes response.body, 'Constructions and Infrastructure Tenders files are ready'
    assert_includes response.body, 'drive.google.com'
  ensure
    ActionMailer::Base.perform_deliveries = true
  end

  test 'an unknown industry or bad details are explained' do
    download(report_type: 'nope')
    assert_includes response.body, 'Please choose your industry'
    download(email: 'not-an-email')
    assert_includes response.body, 'Email is invalid'
    assert_equal 0, Lead.count
  end

  test 'spam gets the usual message but no files, and is kept as spam' do
    ActionMailer::Base.perform_deliveries = false
    download(full_name: 'Visit <a href="https://casino.example">casino</a>')
    assert_not_includes response.body, 'drive.google.com'
    assert_equal ['spam', 'Spam: links or foreign script'], [Lead.sole.status, Lead.sole.note]
  ensure
    ActionMailer::Base.perform_deliveries = true
  end
end

class TenderAlertSidebarTest < ActionDispatch::IntegrationTest
  test 'the sidebar form saves a tender alerts enquiry' do
    post get_relevant_tenders_post_path, params: { fill_ms: 10_000, name: 'Asha', email: 'asha@example.com',
                                                   mobile: '98765 43210', sectors: 'Supply of educational kits' }
    assert_includes response.body, 'Thank you'
    lead = Lead.sole
    assert_equal ['tender_alerts', 'pending', 'Asha'], [lead.topic, lead.status, lead.name]
    assert_equal 'Supply of educational kits', lead.answers['Products or services you offer']
  end
end
