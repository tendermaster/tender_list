require 'test_helper'

# Texts are made up, in the formats BIS licence "Variety" fields use
class Bis::VarietyParserTest < ActiveSupport::TestCase
  def parse(text, standard = 'IS 4984') = Bis::VarietyParser.parse(text, sizes: Bis::Standards.sizes(standard))

  test 'a range means the standard sizes inside it, with PN, SDR and PE grade' do
    grades = parse('Pipe Designation: PE 80 PN 6 DN 40 to 110 mm SDR 17, PE 100 PN 10 DN 63 to 90 mm SDR 17')
    assert_equal [40, 50, 63, 75, 90, 110], grades['sizes_mm']
    assert_equal [6, 10], grades['pn']
    assert_equal [17], grades['sdr']
    assert_equal [80, 100], grades['pe']
  end

  test 'lists, decimals and line breaks inside a list' do
    grades = parse("PE 100 PN 12.5 SDR 13.6 DN 20, 25,\n32 and 40")
    assert_equal [20, 25, 32, 40], grades['sizes_mm']
    assert_equal [12.5], grades['pn']
    assert_equal [13.6], grades['sdr']
  end

  test 'numbers that are not sizes are ignored: pressure, length, thickness' do
    grades = parse('Class 2 (0.40 MPa), Nominal Size: 63 mm, 75 mm and 90 mm, Type A, Length: 6000 mm',
                   'IS 4985')
    assert_equal [63, 75, 90], grades['sizes_mm']
    assert_equal ['2'], grades['classes']
    assert_equal ['A'], grades['types']
  end

  test 'steel tubes: nominal bore and Light / Medium / Heavy' do
    grades = parse('ERW, Size: NB 15 to 25, Heavy and Medium, Thickness 3 mm', 'IS 1239')
    assert_equal [15, 20, 25], grades['sizes_mm']
    assert_equal %w[Heavy Medium], grades['classes']
  end

  test 'a standard without matched sizes keeps the grades only' do
    assert_equal({}, parse('Outside Diameter 406.4 mm to 1219 mm', 'IS 3589'))
  end
end
