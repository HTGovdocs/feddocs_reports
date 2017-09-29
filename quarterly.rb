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
Mongoid.load!("config/mongoid.yml", :production)
Mongo::Logger.logger.level = ::Logger::FATAL
@extractor = Traject::Indexer.new
@extractor.load_config_file('config/traject_publisher.rb')


start = Moped::BSON::ObjectId.from_time(Time.new(2017,7,01))
finish = Moped::BSON::ObjectId.from_time(Time.new(2017,10,01))
numhts = 0
base_url = "https://catalog.hathitrust.org/Record/"
SourceRecord.where(org_code:"miaahdl",
                  deprecated_timestamp:{"$exists":0},
                  :_id.gte => start,
                  :_id.lt => finish).no_timeout.each do | s |
  if s.source['leader'] !~ /^.{7}m/
    next
  end
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
  contributor = ''
  new = false
  s.holdings.each do |ec, holdings|
    holdings.each do | hold |
      if hold[:d].to_i >= 20170701 and hold[:d].to_i < 20171001
        new = true
      end
      digagent = hold[:s]
      contributor = hold[:c]
    end
  end

  # we only want it if the holding is actually new
  if !new
    next
  end
  numhts += 1
  puts [title, author, publisher, pubdate, sudoc, digagent, contributor, base_url+s.local_id, s.ht_availability].join("\t")
end                   

puts numhts

