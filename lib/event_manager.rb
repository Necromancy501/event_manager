require 'csv'
require 'erb'
require 'google/apis/civicinfo_v2'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phones phone_number

  phone_string = phone_number.to_s
  phone_string.gsub!(/[^0-9]/, '')

  case phone_string.length
  when 10
    phone_string
  when 11
    if phone_string[0] == '1'
      phone_string[1..-1]
    end
  else
    '0000000000'
  end
end

def parse_time regdate

  date = regdate.split(' ')[0]
  time = regdate.split(' ')[1]


  # Extract year, month, and day
  year = '20' + date.split('/')[2]
  month = date.split('/')[0]
  day = date.split('/')[1]

  # Extract hour and minute from time
  hour, minute = time.split(':').map(&:to_i)

  time_obj = Time.new(year.to_i, month.to_i, day.to_i, hour, minute)
  time_obj
end

def group_hours regdate_arr
  new = regdate_arr.reduce(Array.new) do |result, regdate|
    time_obj = parse_time regdate
    result.push(time_obj.strftime("%I:00 %p"))
  end
  new.tally
end

def group_days regdate_arr
  new = regdate_arr.reduce(Array.new) do |result, regdate|
    time_obj = parse_time regdate
    result.push(time_obj.strftime("%A"))
  end
  new.tally
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

regdate_arr = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone = clean_phones(row[:homephone])

  regdate_arr.push(row[:regdate])
  p "#{phone}"

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)

end

p group_hours regdate_arr
p group_days regdate_arr


