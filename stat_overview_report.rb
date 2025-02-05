# reports will be generated in a new directory in reports
# bundle exec ruby stat_overview_report.rb
require 'registry/registry_record'
require 'registry/source_record'
require 'pp'
require 'traject'
require 'yaml'
SourceRecord = Registry::SourceRecord
RegistryRecord = Registry::RegistryRecord

# was a full rebuild requested?
full_rebuild = (ARGV.shift == "full")

deprecated_source_ids = {}

# we need a list of currently deprecated source_ids
#connect Mongoid
Mongoid.load!(ENV['MONGOID_CONF'], :production)
Mongo::Logger.logger.level = ::Logger::FATAL
SourceRecord.where(
  org_code:"miaahdl",
  deprecated_timestamp:{"$exists":1}
).no_timeout.pluck('source_id').each do | src_id |
  deprecated_source_ids[src_id] = 1
end

sudoc_classes = []
open("sudoc_classes.txt").each do |line|
  sudoc_classes << line.chomp
end

#  ht_2016-09-28.json  ht_2016-10-01.json  ht_2016-11-01.json  ht_2016-12-01.json  ht_2017-01-01.json  ht_2017-02-01.json`
if full_rebuild
  bibs_out = File.open(__dir__+"/reports/num_bibs.csv", "w")
  bibs_out.puts "Month,Monographs,Serials,Undefined"

  digo_out = File.open(__dir__+"/reports/num_dig.csv", "w")
  digo_out.puts "Month,Full View,Limited View"

  sudoc_out = File.open(__dir__+"/reports/num_sudocs.csv", "w")
  sudoc_out.puts "Month,"+sudoc_classes.join(",")
else
  # append
  bibs_out = File.open(__dir__+"/reports/num_bibs.csv", "a")
  digo_out = File.open(__dir__+"/reports/num_dig.csv", "a")
  sudoc_out = File.open(__dir__+"/reports/num_sudocs.csv", "a")
end

#connect Mongoid
Mongoid.load!(ENV['MONGOID_CONF'], :htonly)
Mongo::Logger.logger.level = ::Logger::FATAL
#indexes for htonly
SourceRecord.index(:local_id=>1)
SourceRecord.create_indexes

# Use traject for a few fields
@extractor = Traject::Indexer::MarcIndexer.new
@extractor.load_config_file('config/traject_publisher.rb')

# Run through the list of snapshots
snaps = Dir.new(__dir__+"/data").sort.filter{ |fins| fins =~ /^ht_\d{4}-\d\d-\d\d.json.gz$/}
unless full_rebuild
  snaps = [snaps.last]
end

snaps.each do | s_f |
  next if s_f !~ /ht.*01.json/

  sr_date = s_f.split('_')[1].split('.')[0].split('-')[0,2].join('-')
  @dbname = "zephir_#{sr_date.gsub(/-/, '')}01"
  puts @dbname
  Mongoid.override_database(@dbname)

  num_full_text = 0
  num_not_full_text = 0
  num_monos = 0
  num_serials = 0
  num_undefined = 0
  suds = Hash.new 0

  SourceRecord.where(
    org_code:"miaahdl",
    deprecated_timestamp:{"$exists":0},
    in_registry:true
  ).no_timeout.each do | src |
    next if deprecated_source_ids.key? src.source_id

    holdings = src.holdings
    src.holdings = holdings
    src.save

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

    holdings.each do |htid, hold|
      if hold[:r] == "pd" or
        hold[:r] == "pdus" or
        hold[:r] == "und-world" or
        hold[:r] =~ /^cc/
        num_full_text += 1
      else
        num_not_full_text += 1
      end
    end
  end #of this source record

  bibs_out.puts [sr_date,num_monos,num_serials,num_undefined].join(",")
  digo_out.puts [sr_date,num_full_text,num_not_full_text].join(",")

  row = sudoc_classes.collect {|s| suds[s]}
  row.unshift(sr_date)
  sudoc_out.puts row.join(",")
end #of this month
