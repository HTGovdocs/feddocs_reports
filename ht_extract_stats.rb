# reports will be generated in a new directory in reports
require 'registry/registry_record'
require 'registry/source_record'
require 'pp'
require 'traject'
require 'yaml'
SourceRecord = Registry::SourceRecord
RegistryRecord = Registry::RegistryRecord

deprecated_source_ids = {}

# we need a list of currently deprecated source_ids
#connect Mongoid
Mongoid.load!("config/mongoid.yml", :production)
Mongo::Logger.logger.level = ::Logger::FATAL
SourceRecord.where(org_code:"miaahdl",
                   deprecated_timestamp:{"$exists":1}).no_timeout.pluck('source_id').each do | src_id |
  deprecated_source_ids[src_id] = 1
end

sudoc_classes = []
open("sudoc_classes.txt").each do |line|
  sudoc_classes << line.chomp
end

#  ht_2016-09-28.json  ht_2016-10-01.json  ht_2016-11-01.json  ht_2016-12-01.json  ht_2017-01-01.json  ht_2017-02-01.json`
bibs_out = open(__dir__+"/reports/num_bibs.csv", "a")
bibs_out.puts "Month,Monographs,Serials,Undefined"

digo_out = open(__dir__+"/reports/num_dig.csv", "a")
digo_out.puts "Month,Full View,Limited View"

sudoc_out = open(__dir__+"/reports/num_sudocs.csv", "a")
sudoc_out.puts "Month,"+sudoc_classes.join(",")

#connect Mongoid
Mongoid.load!("config/mongoid.yml", :development)
Mongo::Logger.logger.level = ::Logger::FATAL
#indexes for htonly
SourceRecord.index(:local_id=>1)
SourceRecord.create_indexes

# Use traject for a few fields
@extractor = Traject::Indexer.new
@extractor.load_config_file('config/traject_publisher.rb')

Dir.foreach(__dir__+"/data") do | s_f |
  next if s_f !~ /ht.*01.json/

  sr_date = s_f.split('_')[1].split('.')[0].split('-')[0,2].join('-')
  puts sr_date
  `mongo htonly --eval "db.dropDatabase()"`
  `mongoimport --db htonly --collection source_records --file #{__dir__+"/data/"+s_f}`

  num_full_text = 0
  num_not_full_text = 0
  num_monos = 0
  num_serials = 0
  num_undefined = 0
  suds = Hash.new 0

  SourceRecord.where(org_code:"miaahdl",
                    deprecated_timestamp:{"$exists":0},
                    in_registry:true).no_timeout.each do | src |
    next if deprecated_source_ids.key? src.source_id

    marc = MARC::Record.new_from_hash(src.source)
    rec = @extractor.map_record(marc)
                    
    if src.source['leader'] =~ /^.{7}m/
      num_monos += 1
    elsif src.source['leader'] =~ /^.{7}s/
      num_serials += 1
    elsif src.source['leader'] =~ /^.{7}d/
      num_undefined += 1
    end

    src.sudocs.each do |s|
      sclass = s.split(/[^A-Z]/)[0]
      if suds.key? sclass
        suds[sclass] += 1
      else
        suds[sclass] = 1
      end
    end

    holdings_seen = []
    src.holdings.each do |ec, holdings|
      holdings.each do |hold|
        #u is the id
        next if holdings_seen.include? hold[:u]
        holdings_seen << hold
        if hold[:r] == "pd" or
          hold[:r] == "pdus" or
          hold[:r] == "und-world" or
          hold[:r] =~ /^cc/
          num_full_text += 1
        else
          num_not_full_text += 1
        end
      end
    end
  end #of this source record
  
  bibs_out.puts [sr_date,num_monos,num_serials,num_undefined].join(",")
  digo_out.puts [sr_date,num_full_text,num_not_full_text].join(",")

  row = sudoc_classes.collect {|s| suds[s]}
  row.unshift(sr_date)
  sudoc_out.puts row.join(",")
end #of this month
