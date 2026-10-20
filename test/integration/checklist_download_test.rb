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

  test 'spam that gets past the captcha is not saved; numbers must look like phone numbers' do
    post checklist_download_path, params: { email: 'x@example.com', report_type: 'construction',
                                            full_name: 'Visit <a href="https://casino.example">casino</a>' }
    post get_relevant_tenders_post_path, params: { name: 'Davidgek', email: 'x@example.com', mobile: '9876543210',
                                                   sectors: 'Лучшие площадки https://dark.example' }
    assert_equal 0, MiscDataStore.count

    post get_relevant_tenders_post_path, params: { name: 'Test', email: 'x@example.com', mobile: '11111111111', sectors: 'Hi' }
    assert_includes response.body, 'valid phone number'
    assert_equal 0, MiscDataStore.count

    # Foreign numbers are fine
    post get_relevant_tenders_post_path, params: { name: 'Momen', email: 'm@example.com', mobile: '01711102539',
                                                   sectors: 'Helical bolster springs' }
    assert_equal 1, MiscDataStore.count

    post get_relevant_tenders_post_path, params: { name: 'Asha', email: 'asha@example.com', mobile: '98765 43210',
                                                   sectors: 'Supply of educational kits' }
    assert_equal 'Asha', MiscDataStore.last.data['name']
  end
end
