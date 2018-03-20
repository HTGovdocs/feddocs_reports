# New monographs ingested into HathiTrust in the last quarter 
require 'registry/registry_record'
require 'registry/source_record'
require 'pp'
require 'traject'
require 'yaml'
require 'moped'
require 'bson'

Moped::BSON = BSON

SourceRecord = Registry::SourceRecord
RegistryRecord = Registry::RegistryRecord

#connect Mongoid
Mongoid.load!(ENV['MONGOID_CONF'], :production)
Mongo::Logger.logger.level = ::Logger::FATAL
@extractor = Traject::Indexer.new
@extractor.load_config_file('config/traject_publisher.rb')


start = Moped::BSON::ObjectId.from_time(Time.new(2018,1,01))
finish = Moped::BSON::ObjectId.from_time(Time.new(2018,4,01))
numhts = 0
base_url = "https://catalog.hathitrust.org/Record/"
SourceRecord.where(org_code:"miaahdl",
                  deprecated_timestamp:{"$exists":0},
                  :_id.gte => start,
                  :_id.lt => finish).no_timeout.each do | s |
  next unless s.monograph?

  marc = MARC::Record.new_from_hash(s.source) 
  rec = @extractor.map_record(marc)
  
  # we only want it if the holding is actually new
  new = false
  rec['dig_date'].each do |dig|
    if dig.to_i >= 20180101 and dig.to_i < 20180401
      new = true
    end
  end
  if !new
    next
  end

  title = (rec['title'] || []).join(', ')
  author = (rec['author'] || []).join(' ')
  publisher = (rec['publisher'] || []).join(' ')
  pubdate = (rec['pub_date'] || []).join(', ')
  sudoc = (s.sudocs || []).join(', ')

  #Digitization Agent
  #assuming only one for a new record
  digagent = ''
  contributor = ''
  s.holdings.each do |ec, holdings|
    holdings.each do | hold |
      digagent = hold[:s]
      contributor = hold[:c]
    end
  end

   numhts += 1
  puts [title, author, publisher, pubdate, sudoc, digagent, contributor, base_url+s.local_id, s.ht_availability].join("\t")
end                   

puts numhts

