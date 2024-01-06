module ApplicationHelper
  include Pagy::Frontend

  def time_left(time)
    # time.is_a?(ActiveSupport::TimeWithZone) ? "#{distance_of_time_in_words(Date.today, time, true, highest_measure_only: true)} left" : '-'
    duration = ((time - Time.zone.now) / 1.day).floor
    if time.is_a?(ActiveSupport::TimeWithZone)
      duration
    end
    # time.is_a?(ActiveSupport::TimeWithZone) and duration >= 0 ? "#{duration} days left" : "Expired #{duration*-1} days ago"
    #   result.submission_close_date.is_a?(ActiveSupport::TimeWithZone) ? "#{distance_of_time_in_words(Date.today,result.submission_close_date, true, highest_measure_only: true)} left" : '-'
  end

  def time_left_text(submission_close_date)
    if time_left(submission_close_date) >= 0
      "#{time_left(submission_close_date)} days left"
    else
      "Expired #{time_left(submission_close_date).abs} days ago"
    end
  end

  def currency_format(amt)
    amt_len = amt.to_s.length
    if amt_len < 6
      amt
    elsif amt_len in 6..7
      amt_rounded = (amt.to_f / 10 ** 5).round(2)
      if amt_rounded.to_s.split('.')[-1] == '0'
        "#{amt_rounded.to_i} Lakh"
      else
        "#{amt_rounded} Lakh"
      end
    else
      amt_rounded = (amt.to_f / 10 ** 7).round(2)
      if amt_rounded.to_s.split('.')[-1] == '0'
        "#{amt_rounded.to_i} Crore"
      else
        "#{amt_rounded} Crore"
      end
    end
  end

  def generate_faq(data)
    JSON.pretty_generate(
      '@context': 'https://schema.org',
      '@type': 'FAQPage',
      'mainEntity': data.each_with_index do |ques|
        {
          '@type': 'Question',
          'name': ques[:name],
          'acceptedAnswer': {
            '@type': 'Answer',
            'text': ques[:ans]
          }
        }
      end
    )
  end

  def is_tender_id?(string)
    if string.length <= 40 and string.scan('/').length >= 3
      true
    else
      false
    end
  end

  # TODO: cache value, memoize
  # TODO: add gem keywords
  def gem_keyword_list
    ""
  end

  def home_keyword_list
    "Empanelment of Agency
Civil construction
IT tenders
Electrical equipment and supplies
Office supplies and furniture
Medical equipment and supplies
door to door
unskilled labour
Manpower supply
audit firm
community sanitary complex
Supply of chemicals
contractual labour
watchman
beautification of municipal garden
pesticides
Street vendors
service provider
public school
Vehicle contract
impact assessment
professional services
garden maintenance
Supply of uniforms
Plantation of Trees
stationary supply
contract worker
Security Guards
gardener
stray castration vaccination and sterilization dogs
Waste Disposal
waste collection
Empanelment of vendor
Empanelment of service provider
Jal Jeevan Mission service
Skill Development
Skill training
house keeping
Swachh Bharat Mission
#{gem_keyword_list}
    ".split("\n").sort.map { |state| state.strip }.reject(&:empty?)
  end

  def get_sector_list
    "Construction materials
IT hardware and software
Office equipment and furniture
Medical supplies and equipment
Pharmaceuticals and healthcare products
Agricultural equipment and supplies
Food and beverage products
Textiles and clothing
Electrical equipment and supplies
Security and surveillance equipment
Printing and publishing services
Transportation and logistics services
Chemicals and industrial supplies
Renewable energy products and services
Water treatment equipment and supplies
Construction materials
Office equipment and supplies
Industrial machinery and equipment
Electrical and electronics components
Pharmaceuticals and medical supplies
Food and agriculture products
Textiles and clothing
Printing and publishing services
Transportation equipment and services
Security equipment and services
Energy and power generation equipment and services
Information technology and software services
Consultancy services
Environmental services and products
Chemicals and fertilizers
Education and skill-building services
Healthcare and medical services
Community development and livelihood promotion
Environment and sustainability projects
Disaster relief and humanitarian aid services
Women's empowerment and gender equality initiatives
Child welfare and protection services
Rural development and agriculture projects
Human rights and advocacy services
Capacity building and organizational development services
Non-profit organizations in India
Charitable organizations in India
NGO in India
Volunteer work in India
Social welfare organizations in India
Donation in India
NGO registration in India
Indian non-profit sector
Community service in India
India charity events
Non-profit jobs in India
Non-profit fundraising in India
Indian philanthropy
Corporate social responsibility in India
Non-profit grants in India
".split("\n").sort.map { |state| state.strip }
  end

  def get_state_list
    "Andhra Pradesh
Arunachal Pradesh
Assam
Bihar
Chhattisgarh
Goa
Gujarat
Haryana
Himachal Pradesh
Jharkhand
Karnataka
Kerala
Madhya Pradesh
Maharashtra
Manipur
Meghalaya
Mizoram
Nagaland
Odisha
Punjab
Rajasthan
Sikkim
Tamil Nadu
Telangana
Tripura
Uttar Pradesh
Uttarakhand
West Bengal

Andaman and Nicobar Islands
Chandigarh
Dadra and Nagar Haveli and Daman and Diu
Delhi
Jammu and Kashmir
Ladakh
Lakshadweep
Puducherry

".split("\n").sort.map { |state| state.strip }
  end

  def get_city_list
    "Mumbai
Delhi
Bangalore
Hyderabad
Ahmedabad
Chennai
Kolkata
Surat
Vadodara
Pune
Jaipur
Lucknow
Kanpur
Nagpur
Indore
Thane
Bhopal
Visakhapatnam
Pimpri-Chinchwad
Patna
Ghaziabad
Ludhiana
Agra
Nashik
Faridabad
Meerut
Rajkot
Kalyan-Dombivli
Vasai-Virar
Varanasi
Srinagar
Aurangabad
Dhanbad
Amritsar
Navi Mumbai
Allahabad
Howrah
Ranchi
Gwalior
Jabalpur
Coimbatore
Vijayawada
Jodhpur
Madurai
Raipur
Kota
Chandigarh
Guwahati
Solapur
Hubli–Dharwad
Bareilly
Mysore
Moradabad
Gurgaon
Aligarh
Jalandhar
Tiruchirappalli
Bhubaneswar
Salem
Mira-Bhayandar
Thiruvananthapuram
Bhiwandi
Saharanpur
Gorakhpur
Guntur
Amravati
Bikaner
Noida
Jamshedpur
Bhilai
Warangal
Cuttack
Firozabad
Kochi
Bhavnagar
Dehradun
Durgapur
Asansol
Nanded
Kolhapur
Ajmer
Gulbarga
Loni
Ujjain
Siliguri
Ulhasnagar
Jhansi
Sangli-Miraj & Kupwad
Jammu
Nellore
Mangalore
Belgaum
Jamnagar
Tirunelveli
Malegaon
Gaya
Ambattur
Jalgaon
Udaipur
Maheshtala
Tiruppur
Davanagere
Kozhikode
Kurnool
Akola
Rajpur Sonarpur
Bokaro
Bellary
Patiala
South Dum Dum
Rajarhat
Bhagalpur
Agartala
Muzaffarnagar
Bhatpara
Latur
Panihati
Dhule
Rohtak
Korba
Bhilwara
Berhampur
Muzaffarpur
Ahmednagar
Mathura
Kollam
Avadi
Kadapa
Rajahmundry
Bilaspur
Kamarhati
Shahjahanpur
Bijapur
Rampur
Shimoga
Chandrapur
Junagadh
Thrissur
Alwar
Bardhaman
Kulti
Kakinada
Nizamabad
Parbhani
Tumkur
Hisar
Uzhavarkarai
Bihar Sharif
Darbhanga
Panipat
Aizawl
Bally
Dewas
Ichalkaranji
Karnal
Bathinda
Jalna
Kirari Suleman Nagar
Purnia
Satna
Mau
Barasat
Sonipat
Farrukhabad
Sagar
Rourkela
Durg
Imphal
Ratlam
Hapur
Arrah
Anantapur
Karimnagar
Etawah
Ambarnath
North Dum Dum
Bharatpur
Begusarai
New Delhi
Gandhidham
Baranagar
Tiruvottiyur
Pondicherry
Sikar
Thoothukudi
Rewa
Karur
Mirzapur
Raichur
Pali
Ramagundam
Silchar
Haridwar
Vijayanagaram
Tenali
Nagercoil
Sri Ganganagar
Karawal Nagar
Mango
Thanjavur
Bulandshahr
Uluberia
Katni
Sambhal
Singrauli
Nadiad
Secunderabad
Naihati
Yamunanagar
Bidhannagar
Pallavaram
Bidar
Munger
Panchkula
Burhanpur
Kharagpur
Dindigul
Gandhinagar
Hospet
Nangloi Jat
Malda
Ongole
Eluru
Deoghar
Chhapra
Puri
Haldia
Khandwa
Nandyal
Morena
Amroha
Anand
Bhiwani
Bhind
Bhalswa Jahangir Pur
Madhyamgram
Berhampore
Morbi
Fatehpur
Raebareli
Khora, Ghaziabad
Chittoor
Bhusawal
Orai
Bahraich
Phusro
Vellore
Mehsana
Khammam
Sambalpur
Raiganj
Sirsa
Danapur
Serampore
Sultan Pur Majra
Guna
Jaunpur
Panvel
Shivpuri
Surendranagar Dudhrej
Unnao
Chinsurah
Alappuzha
Kottayam
Valsad
Machilipatnam
Shimla
Midnapore
Firozpur
Mohali
Adoni
Jind
Udupi
Katihar
Vapi
Budaun
Batala
Mahbubnagar
Erode
Saharsa
Thanesar
Dibrugarh
Jorhat
Hindupur
Nagaon
Pathankot
Hajipur
Sasaram
Moga
Abohar
Kaithal
Hazaribagh
Bhimavaram
Rewari
Port Blair
Kumbakonam
Malerkotla
Bongaigaon
Raigarh
Dehri
Madanapalle
Siwan
Bettiah
Ramgarh
Palwal
Khanna
Tinsukia
Guntakal
Srikakulam
Motihari
Dimapur
Dharmavaram
Medininagar
Satara
Gudivada
Phagwara
Pudukkottai
Muktsar
Barnala
Hosur
Narasaraopet
Suryapet
Giridih
Faridkot
Hoshiarpur
Miryalaguda
Anantnag
Tadipatri
Karaikudi
Kishanganj
Gangavathi
Jamalpur
Ballia
Kavali
Tadepalligudem
Amaravati
Buxar
Tezpur
Jehanabad
Kapurthala
Aurangabad
Gangtok
Vasco Da Gama
".split("\n").sort.map { |state| state.strip }
  end

  def get_states
    "Andhra Pradesh
    Arunachal Pradesh
    Assam
    Bihar
    Chhattisgarh
    Goa
    Gujarat
    Haryana
    Himachal Pradesh
    Jharkhand
    Karnataka
    Kerala
    Madhya Pradesh
    Maharashtra
    Manipur
    Meghalaya
    Mizoram
    Nagaland
    Odisha
    Punjab
    Rajasthan
    Sikkim
    Tamil Nadu
    Telangana
    Tripura
    Uttar Pradesh
    Uttarakhand
    West Bengal
    Andaman and Nicobar Islands
    Chandigarh
    Dadra and Nagar Haveli and Daman and Diu
    Delhi
    Jammu and Kashmir
    Ladakh
    Lakshadweep
    Puducherry".split("\n").sort.map { |state| state.strip }
  end

  def get_sectors
    "Central Government
    Defence
    Co-operatives
    Corporations
    Railway
    School & Colleges
    Associations
    Joint sector Semi-Government
    Universities
    Research Institute
    State Government
    Private sector
    Trust
    Bank
    PSU".split("\n").sort.map { |sector| sector.strip }
  end

end
