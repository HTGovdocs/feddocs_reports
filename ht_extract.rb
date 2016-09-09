require 'registry_record'
require 'source_record'
require 'pp'
require 'traject'
require 'yaml'

#load the HT we want to work with
source_records = ARGV.shift
`mongo htonly --eval "db.dropDatabase()"`
`mongoimport --db htonly --collection source_records --file #{source_records}`
# Make our report directory if it doesn't already exist
sr_date = source_records.split('_')[1]
rep_dir = __dir__+"reports/#{sr_date}"
Dir.mkdir(rep_dir) 
unless File.exists? (rep_dir)

#connect Mongoid
Mongoid.load!("config/mongoid.yml", :development)
Mongo::Logger.logger.level = ::Logger::FATAL

#load some mappings
contribs = YAML.load(__dir__+'mappings/contributors.yml')
digitizers = YAML.load(__dir__+'mappings/digitizing.yml')
rights = YAML.load(__dir__+'mappings/rights.yml')

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

summ_out = open(rep_dir+'/summary.txt', 'w')
rights_out = open(rep_dir+'/rights.tsv', 'w')
dig_out = open(rep_dir+'/digitizing.tsv', 'w')
contrib_out = open(rep_dir+'/contribors.tsv', 'w')
pub_out = open(rep_dir+'/publisher.tsv', 'w')
normpub_out = open(rep_dir+'/normpublisher.tsv', 'w')
place_out = open(rep_dir+'/place.tsv', 'w')
sub_out = open(rep_dir+'/subject.tsv', 'w')
corp_out = open(rep_dir+'/corp_auth.tsv', 'w')
years_out = open(rep_dir+'/yearpub.tsv', 'w')

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
      rights_count[rights[hold[:r]]] ||= 0
      rights_count[rights[hold[:r]]] += 1
      digitizing_agent[digitizers[hold[:s]]] ||= 0
      digitizing_agent[digitizers[hold[:s]]] += 1
      contributors[contribs[hold[:c].downcase]] ||= 0
      contributors[contribs[hold[:c].downcase]] += 1
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

rights_count.sort_by {|r, cnt| cnt}.reverse
    .each {|r,cnt| rights_out.puts "#{r}\t#{cnt}"}
contributors.sort_by {|c, cnt| cnt}.reverse
    .each {|c,cnt| contrib_out.puts "#{c}\t#{cnt}"}
digitizing_agent.sort_by {|s, cnt| cnt}.reverse
    .each {|s,cnt| dig_out.puts "#{s}\t#{cnt}"}
#eliminate questionable publishing years
holding_years.select { |y, cnt| y.to_s.to_i >= 1789 && y.to_s.to_i <= 2016 }
    .sort_by {|y, cnt| y}.reverse
    .each {|y,cnt| years_out.puts "#{y}\t#{cnt}"}
norm_publisher_counts.sort_by {|k,v| v}.reverse
    .each {|pub,cnt| normpub_out.puts "#{pub}\t#{cnt}"}
publisher_counts.sort_by {|k,v| v}.reverse
    .each {|pub,cnt| pub_out.puts "#{pub}\t#{cnt}"}
place_of_publication.sort_by{|k,v| v}.reverse
    .each {|place,cnt| place_out.puts "#{place}\t#{cnt}"}
