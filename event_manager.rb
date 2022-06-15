require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def clean_phone_number(number)
  return nil if number.length < 10 || number.length > 11
  if number.length == 11
    return number[1..-1] if number[0] == '1'
    return nil
  end 
end


def time_targeting(times)
  hour_obj = {}
  day_obj = {}
  times.each do |time|
    date = Date.strptime(time.split(' ')[0], "%m/%d/%y")
    weekday = date.strftime('%A')
    day_obj[weekday] = day_obj[weekday] ? day_obj[weekday] + 1 : 1 
    hour = Time.parse(time.split(' ')[1], date).hour.to_s + ":00"
    hour_obj[hour] = hour_obj[hour] ? hour_obj[hour] + 1 : 1
  end
  hour_arr = []
  hour_obj.each_pair do |key, value|
    hour_arr << [key, value]
  end
  hour_arr.sort!{|a, b| b[1] - a[1]}
  day_arr = []
  day_obj.each_pair do |key, value|
    day_arr << [key, value]
  end
  day_arr.sort!{|a, b| b[1] - a[1]}
  { days: day_arr, hours: hour_arr }
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

times = []
contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  times << row[:regdate]
  # p row
end

p time_targeting(times)

# ruby lib/event_manager.rb