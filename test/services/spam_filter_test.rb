require 'test_helper'

# Cases modelled on real form submissions (names and addresses changed): spam
# the forms received, and customers who must get through
class SpamFilterTest < ActiveSupport::TestCase
  def reason(name: 'Ravi Kumar', email: 'ravi@gmail.com', texts: ['construction'], headers: {})
    SpamFilter.reason(honeypot: nil, fill_ms: 10_000, email:, name:, texts: [name, email, *texts], headers:)
  end

  test 'real customers get through' do
    assert_nil reason
    assert_nil reason(name: 'Shree Om Industries Pvt. Ltd', email: 'sales@example.co.in', texts: ['supply of 1.1. kv grade xlpe cables'])
    assert_nil reason(name: 'sunrise healthcare&Diagnostics pvt.Ltd', texts: ['NGO'])
    assert_nil reason(name: 'AnilRaghavan', texts: ['manpower'])                 # one word, but not a bot name
    assert_nil reason(name: 'ahmed hassan', email: 'eastlinegroupco@gmail.com', texts: ['furnance'])
    assert_nil reason(name: 'DavidOrnag', texts: ['supply'])                    # one weak signal is not enough
    assert_nil reason(texts: ['supply, valves, construction chemicals, material handling, safety equipment, welding'])
  end

  test 'hard rules' do
    assert_equal 'spam email domain', reason(email: 'w@mail.ru')
    assert_equal 'spam email domain', reason(email: 'x@rambler.ru ')
    assert_equal 'spam email domain', reason(email: 'p@fuhrenmail.com')
    assert_equal 'web address as the name', reason(name: 'homemade.lululu.win')
    assert_equal 'blog comment spam', reason(name: 'Holyfield', texts: ['Very good post! We are linkking to this particularly great post on our site.'])
    assert_equal 'blog comment spam', reason(texts: ['If you desie to obtain mch fromm this paragraph hen you have to apply these strategies'])
    assert_equal 'links or foreign script', reason(texts: ['Фурнитура высокого качества'])
  end

  test 'weak signals count in pairs' do
    russian = { 'accept-language' => 'ru-RU,ru;q=0.9,en;q=0.8' }
    assert_equal 'made-up name and foreign browser language', reason(name: 'Augustblw', texts: [''], headers: russian)
    assert_equal 'made-up name and essay-length answer',
                 reason(name: 'KillianUnrerefut', texts: ['What other data sources would be useful ' * 10])
    assert_nil reason(headers: russian)                                        # a Russian browser alone
    assert_nil reason(headers: { 'accept-language' => 'en-IN,en;q=0.9,hi;q=0.8' }, name: 'DavidOrnag')
  end
end
