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
Mongoid.load!("config/mongoid.yml", :development)
Mongo::Logger.logger.level = ::Logger::FATAL
@extractor = Traject::Indexer.new
@extractor.load_config_file('config/traject_publisher.rb')


start = Moped::BSON::ObjectId.from_time(Time.new(2017,01,01))
finish = Moped::BSON::ObjectId.from_time(Time.new(2017,04,01))
numhts = 0
base_url = "https://catalog.hathitrust.org/Record/"
SourceRecord.where(org_code:"miaahdl",
                  deprecated_timestamp:{"$exists":0},
                  :_id.gte => start,
                  :_id.lt => finish).no_timeout.each do | s |
  if s.source['leader'] !~ /^.{7}m/
    next
  end
  numhts += 1
  marc = MARC::Record.new_from_hash(s.source) 
  rec = @extractor.map_record(marc)

  #title
  if rec['title']
    title = rec['title'].join(' ')
  else
    title = ''
  end

  #Author
  if rec['author']
    author = rec['author'].join(' ')
  else
    author = ''
  end

  #Publisher
  if rec['publisher']
    publisher = rec['publisher'].join(' ')
  else
    publisher = ''
  end

  #Publication Date
  pubdate = rec['pub_date'] || ""

  #SuDoc number (if available)
  if s.sudocs.count == 0 
    sudoc = ""
  else
    sudoc = s.sudocs.join(', ')
  end

  #Digitization Agent
  #assuming only one for a new record
  digagent = ''
  s.holdings.each do |ec, holdings|
    holdings.each do | hold |
      digagent = hold[:s]
    end
  end

  puts [title, author, publisher, pubdate, sudoc, digagent, base_url+s.local_id, s.ht_availability].join("\t")
end                   

puts numhts

