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
end
