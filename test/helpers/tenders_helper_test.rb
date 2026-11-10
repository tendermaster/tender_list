require 'test_helper'

# Titles from real tenders (the alert form on closed tender pages is
# prefilled with what tender_topic makes of them)
class TendersHelperTest < ActionView::TestCase
  include ApplicationHelper

  def topic(title, description = nil)
    tender_topic(Tender.new(title:, description:))
  end

  test 'what the tender is for, without boilerplate' do
    assert_equal 'Structure Refurbishment and Painting Work', topic('PMJTS23015 - Structure Refurbishment and Painting Work at NRPL Tikrikalan')
    assert_equal 'Construction of godowns', topic('Custom Bid for Services - Construction of godowns for FCI Storage requirements')
    assert_equal 'Medical Equipment', topic('Supply and Commissioning of Medical Equipment for Physical Medicine and Rehabilitation')
    assert_equal 'Mahindra XUV 700 or Similar Vehicle', topic('Supply of Mahindra XUV 700 or Similar Vehicle Make Complete')
    assert_equal 'Answer book', topic('E-tender for answer book')
    assert_equal 'Static water tank', topic('PROVN OF STATIC WATER TANK AT AFS THANJAVUR')
    assert_equal '4 types of Medical Equipments', topic('Procurement of 4(Four) types of Medical Equipments for the Department')
    assert_equal 'Repair-Reclamation of Damaged Power Transformers', topic('Rate Contract for Repair-Reclamation of Damaged Power Transformers of NTPC')
    assert_equal 'Construction of ipb rasta', topic('CONSTRUCTION OF IPB RASTA P...')
  end

  test 'the description when the title is a reference number; nothing when neither says' do
    assert_equal 'Protection work of left and right', topic('WBIW/EE/TLBD/NIT-6e/23-24,Sl-1', 'Protection_work_of_left_and_right_side_downstream')
    assert_nil topic('WBIW/EE/TLBD/NIT-6e/23-24,Sl-1')
    assert_nil topic('Tender')
    assert_nil topic('')
  end

  test 'a reference number with spaces in it is not a topic' do
    assert_nil topic('0110500305-PROJECTS/CPX-B/BOF GCP SLUDGE/SMS/1293')
  end

  test 'amounts in rupees; nothing when the portal gave none' do
    assert_equal '₹99,926', rupees('99926')
    assert_equal '₹1.25 Lakh', rupees('125000')
    assert_equal '₹2.5 Crore', rupees(25_000_000)
    assert_nil rupees(nil)
    assert_nil rupees('-')
    assert_equal 'As per document', rupees('As per document')
  end

  test 'cards are headed by the description when the title is a reference number' do
    tender = Tender.new(title: 'HPPTCL/PIU Sarabai/Tenders/SMS/2026-27/14', description: 'Construction of Residential Quarters')
    assert_equal 'Construction of Residential Quarters', tender_card_heading(tender)
    assert_equal 'Supply of led lights', tender_card_heading(Tender.new(title: 'SUPPLY OF LED LIGHTS'))
  end

  test 'days until a portal date count calendar days in India' do
    travel_to Time.utc(2026, 11, 10, 11, 37) do # 17:07 IST
      assert_equal 1, ist_days_until(Time.utc(2026, 11, 11, 11)) # 11 Nov, 11:00 IST
      assert_equal 0, ist_days_until(Time.utc(2026, 11, 10, 23))
      assert_equal(-1, ist_days_until(Time.utc(2026, 11, 9, 23)))
    end
  end
end
