require 'test_helper'

class ChecklistDownloadTest < ActionDispatch::IntegrationTest
  test 'emails the files when mail is on' do
    assert_enqueued_emails 1 do
      post checklist_download_path, params: { email: 'lead@example.com', report_type: 'construction' }
    end
    assert_includes response.body, 'Please Check your email'
  end

  test 'shows the files on the page while mail is off' do
    ActionMailer::Base.perform_deliveries = false
    assert_no_enqueued_emails do
      post checklist_download_path, params: { email: 'lead@example.com', report_type: 'construction' }
    end
    assert_includes response.body, 'Constructions and Infrastructure Tenders files are ready'
    assert_includes response.body, 'drive.google.com'
  ensure
    ActionMailer::Base.perform_deliveries = true
  end
end
