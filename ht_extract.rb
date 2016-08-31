require 'registry_record'
require 'source_record'
require 'pp'
require 'traject'

@extractor = Traject::Indexer.new
@extractor.load_config_file('config/traject_publisher.rb')

Mongoid.load!("config/mongoid.yml", :development)

Mongo::Logger.logger.level = ::Logger::FATAL

bib_rec_count = 0
item_count = 0
dig_obj_count = 0
sudoc_count = 0
mono_count = 0
serial_count = 0
year_cataloged = {}
 
leader = {}

summ_stats = {}
summ_stats[:r] = {}
summ_stats[:s] = {}
summ_stats[:c] = {}
summ_stats[:y] = {}
summ_stats[:publisher] = {}
summ_stats[:subject] = {}
summ_stats[:place_of_publication] = {}

summ_out = open(ARGV.shift, 'w')
pub_out = open('ht_publisher.txt', 'w')
place_out = open('ht_place.txt', 'w')
sub_out = open('ht_subject.txt', 'w')
corp_out = open('ht_corp_auth.txt', 'w')

# all HT records 
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
      summ_stats[:publisher][pub] ||= 0
      summ_stats[:publisher][pub] += 1
    end
  end
  if rec['subject']
    rec['subject'].each do | sub |
      summ_stats[:subject][sub] ||= 0
      summ_stats[:subject][sub] += 1
    end
  end
  if rec['place_of_publication']
    rec['place_of_publication'].each do |place|
      summ_stats[:place_of_publication][place] ||= 0
      summ_stats[:place_of_publication][place] += 1
    end 
  end
  if rec['corp_author']
    #PP.pp Normalize.corporate(rec['corp_author'].map{ |sf| Normalize.corporate(sf)}.join(' '), false)
  end
  

  #we want a tab delimited copy of this
  src.holdings.each do |ec, holdings|
    holdings.each do |hold|
      dig_obj_count += 1
      summ_stats[:r][hold[:r]] ||= 0
      summ_stats[:r][hold[:r]] += 1
      summ_stats[:s][hold[:s]] ||= 0
      summ_stats[:s][hold[:s]] += 1
      summ_stats[:c][hold[:c].downcase] ||= 0
      summ_stats[:c][hold[:c].downcase] += 1
      summ_stats[:y][hold[:y]] ||= 0
      summ_stats[:y][hold[:y]] += 1
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
summ_stats[:r].each {|r,cnt| summ_out.puts "\t#{r}: #{cnt}"}
summ_out.puts "Contributors:"
summ_stats[:c].each {|c,cnt| summ_out.puts "\t#{c}: #{cnt}"}
summ_out.puts "Digitizing Agent:"
summ_stats[:s].each {|s,cnt| summ_out.puts "\t#{s}: #{cnt}"}
summ_out.puts "Years:"
summ_stats[:y].each {|y,cnt| summ_out.puts "\t#{y}: #{cnt}"}
#summ_out.puts "Publisher:"
summ_stats[:publisher].sort_by {|k,v| v}.reverse.each {|pub,cnt| pub_out.puts "#{cnt}: #{pub}"}
summ_stats[:place_of_publication].sort_by{|k,v| v}.reverse.each {|place,cnt| place_out.puts "#{cnt}: #{place}"}
summ_stats[:subject].sort_by{|k,v| v}.reverse.each {|subject,cnt| sub_out.puts "\t#{cnt}: #{subject}"}

PP.pp year_cataloged 
