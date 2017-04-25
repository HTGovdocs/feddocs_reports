require 'registry/registry_record'
require 'registry/source_record'

SourceRecord = Registry::SourceRecord
RegistryRecord = Registry::RegistryRecord

#connect Mongoid
Mongoid.load!("config/mongoid.yml", :development)
Mongo::Logger.logger.level = ::Logger::FATAL

SourceRecord.where(org_code:"miaahdl",
                   in_registry:true,
                  deprecated_timestamp:{"$exists":0}).no_timeout.each do | s |
  s.holdings.each do |ec, holdings|
    holdings.each do | hold |
      puts hold[:u]
    end
  end

end                   
