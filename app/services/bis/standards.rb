module Bis
  # The IS standards imported for products.sigmatenders.com, with the sizes
  # each standard defines. Licence texts give sizes as lists or ranges
  # ("DN 40 to 180"); a range means the standard sizes inside it.
  module Standards
    HDPE = [16, 20, 25, 32, 40, 50, 63, 75, 90, 110, 125, 140, 160, 180, 200, 225, 250, 280, 315, 355, 400, 450, 500,
            560, 630, 710, 800, 900, 1000, 1200].freeze
    PVC = [20, 25, 32, 40, 50, 63, 75, 90, 110, 125, 140, 160, 180, 200, 225, 250, 280, 315, 355, 400, 450, 500, 560,
           630].freeze
    SWR = [40, 50, 63, 75, 90, 110, 125, 140, 160, 200, 250, 315].freeze
    CASING = [40, 50, 65, 80, 100, 125, 150, 175, 200, 250, 300, 350, 400, 450, 500].freeze
    CPVC = [15, 20, 25, 32, 40, 50, 65, 80, 100, 125, 150].freeze
    CONDUIT = [16, 20, 25, 32, 40, 50, 63].freeze
    # Steel tubes by nominal bore (NB, mm)
    STEEL_NB = [6, 8, 10, 15, 20, 25, 32, 40, 50, 65, 80, 90, 100, 125, 150, 200, 250, 300].freeze

    # IS number => sizes (nil: sizes aren't matched for this standard)
    SIZES = {
      'IS 4984' => HDPE,     # PE pipes for water supply
      'IS 14333' => HDPE,    # PE pipes for sewerage and industrial effluent
      'IS 14885' => HDPE,    # PE pipes for gas
      'IS 15801' => HDPE,    # PE micro-duct and PLB duct
      'IS 4985' => PVC,      # uPVC pressure pipes
      'IS 15328' => PVC,     # uPVC non-pressure underground drainage
      'IS 13592' => SWR,     # uPVC soil, waste and rain water (SWR)
      'IS 12818' => CASING,  # uPVC casing and screen pipes for borewells
      'IS 15778' => CPVC,    # CPVC hot and cold water pipes
      'IS 9537' => CONDUIT,  # electrical conduits
      'IS 1239' => STEEL_NB, # steel (GI/black) tubes
      'IS 1161' => STEEL_NB, # steel tubes for structural purposes
      'IS 3589' => nil,      # large welded steel pipes, given by outside diameter
      'IS 15500' => nil      # deep-well hand pumps (India Mark II / III)
    }.freeze

    def self.imported?(is_number) = SIZES.key?(is_number)

    def self.sizes(is_number) = SIZES[is_number]

    # "IS 1180 : PART 1 : 2014" => "IS 1180"
    def self.is_number(standard) = standard.to_s[/\AIS\s*(\d+)/i, 1]&.then { "IS #{_1}" }
  end
end
