require 'registry_record'
require 'source_record'
require 'pp'
require 'traject'

#load the HT we want to work with
source_records = ARGV.shift
`mongo htonly --eval "db.dropDatabase()"`
`mongoimport --db htonly --collection source_records --file #{source_records}`

#connect Mongoid
Mongoid.load!("config/mongoid.yml", :development)
Mongo::Logger.logger.level = ::Logger::FATAL


# Use traject for a few fields
@extractor = Traject::Indexer.new
@extractor.load_config_file('config/traject_publisher.rb')


bib_rec_count = 0
item_count = 0
dig_obj_count = 0
sudoc_count = 0
mono_count = 0
serial_count = 0
year_cataloged = {}
 
leader = {}

rights_count = {}
digitizing_agent = {}
contributors = {}
holding_years = {}
norm_publisher_counts = {}
publisher_counts = {}
subject_counts = {}
place_of_publication = {}

summ_out = open(ARGV.shift, 'w')
pub_out = open('ht_publisher.txt', 'w')
place_out = open('ht_place.txt', 'w')
sub_out = open('ht_subject.txt', 'w')
corp_out = open('ht_corp_auth.txt', 'w')

SourceRecord.where(org_code:"miaahdl",
                  deprecated_timestamp:{"$exists":0},
                  in_registry:true).no_timeout.each do | src |
  marc = MARC::Record.new_from_hash(src.source)
  rec = @extractor.map_record(marc)

  year_cataloged[rec['catalog_year']] ||= 0
  year_cataloged[rec['catalog_year']] += 1 

  bib_rec_count += 1
  leader[src.source['leader'][7]] ||= 0
  leader[src.source['leader'][7]] += 1 

  if src.source['leader'] =~ /^.{7}m/
    mono_count += 1
  elsif src.source['leader'] =~ /^.{7}s/
    serial_count += 1
  elsif src.source['leader'] =~ /^.{7}d/
    PP.pp src.source.to_json
  end

  if src.enum_chrons.count == 0 
    item_count += 1
  else
    item_count += src.enum_chrons.count
  end

  if rec['publisher']
    rec['publisher'].each do |pub|
      publisher_counts[pub] ||= 0
      publisher_counts[pub] += 1
      normed = Normalize.corporate(pub, false)
      norm_publisher_counts[normed] ||= 0
      norm_publisher_counts[normed] += 1
    end
  end
  if rec['subject']
    rec['subject'].each do | sub |
      subject_counts[sub] ||= 0
      subject_counts[sub] += 1
    end
  end
  if rec['place_of_publication']
    rec['place_of_publication'].each do |place|
      place.upcase!
      place.gsub!(/\./,'')
      place_of_publication[place] ||= 0
      place_of_publication[place] += 1
    end 
  end
  if rec['corp_author']
    #PP.pp Normalize.corporate(rec['corp_author'].map{ |sf| Normalize.corporate(sf)}.join(' '), false)
  end
  
  #holdings level counts
  src.holdings.each do |ec, holdings|
    holdings.each do |hold|
      dig_obj_count += 1
      rights_count[hold[:r]] ||= 0
      rights_count[hold[:r]] += 1
      digitizing_agent[hold[:s]] ||= 0
      digitizing_agent[hold[:s]] += 1
      contributors[hold[:c].downcase] ||= 0
      contributors[hold[:c].downcase] += 1
      holding_years[hold[:y]] ||= 0
      holding_years[hold[:y]] += 1

      #if we want a tab delimited copy of this
=begin
      puts [src.local_id,
            hold[:c].downcase,
            hold[:s],
            hold[:r],
            hold[:u],
            hold[:z],
            hold[:y],
            ec].join("\t")
=end
    end
  end
end

PP.pp(leader, summ_out)

summ_out.puts "# of Bibliographic Records: #{bib_rec_count}"
summ_out.puts "#{mono_count} monograph records. #{serial_count} serial records."
summ_out.puts "# of unique items represented in the Registry: #{item_count}"
summ_out.puts "# of digital objects (974): #{dig_obj_count}"
summ_out.puts "Rights determinations:"
rights_count.each {|r,cnt| summ_out.puts "\t#{r}: #{cnt}"}
summ_out.puts "Contributors:"
contributors.each {|c,cnt| summ_out.puts "\t#{c}: #{cnt}"}
summ_out.puts "Digitizing Agent:"
summ_out.puts "Contributors:"
contributors.each {|c,cnt| summ_out.puts "\t#{c}: #{cnt}"}
summ_out.puts "Digitizing Agent:"
digitizing_agent.each {|s,cnt| summ_out.puts "\t#{s}: #{cnt}"}
summ_out.puts "Years:"
holding_years.each {|y,cnt| summ_out.puts "\t#{y}: #{cnt}"}
summ_out.puts "Publisher:"
norm_publisher_counts.sort_by {|k,v| v}.reverse.each {|pub,cnt| summ_out.puts "#{cnt}: #{pub}"}
#these are too big to stick in summ stats.
publisher_counts.sort_by {|k,v| v}.reverse.each {|pub,cnt| pub_out.puts "#{cnt}: #{pub}"}
place_of_publication.sort_by{|k,v| v}.reverse.each {|place,cnt| place_out.puts "#{cnt}: #{place}"}
