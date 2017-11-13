# to run: 
# bundle exec ruby ht_extract.rb data/<ht source date>
# reports will be generated in a new directory in reports
require 'registry/registry_record'
require 'registry/source_record'
require 'pp'
require 'traject'
require 'yaml'
SourceRecord = Registry::SourceRecord
RegistryRecord = Registry::RegistryRecord

def setComprehensiveness( series )
  #some the ht_ids won't exist at time of HT source records run. 
  ht_ids = []
  #use current Production database ('htgd')
  Mongoid.override_database("htgd")
  RegistryRecord.where(deprecated_timestamp:{"$exists":0},
                 series:series).each do | reg | 
    @compness[series.to_s][:corpus] += 1
    if ['Full View','Limited View'].include? reg.ht_availability 
      ids = (reg.ht_ids_fv + reg.ht_ids_lv).flatten.uniq.map {|i| i.gsub(/^0+/, '') }
      ht_ids << ids
    end
  end

  #use specified source date with database htonly
  Mongoid.override_database("htonly")
  ht_ids.each do | ids |
    #look in the archived source records for these ht_ids
    if SourceRecord.where(local_id:{"$in":ids}).count > 0
      @compness[series.to_s][:ht] += 1
    end
  end
end

def normalizePubPlace( place )
  place.gsub!(/\(.*\)?/, '') #remove parentheses
  #junk
  place.gsub!(/\[ETC\]/, '')
  place.gsub!(/[\[\]]/, '') #remove brackets
  place.gsub!(/\?/, '') # a guess is good enough
  place.sub!(/:.*/, '') # trailing garbage
  place.sub!(/, USA$/, '') #don't need it
  place.sub!(/^CITY OF /, '')
  place.sub!(/ ,/, ',')
  place.sub!(/FOR SALE BY.*TECHNICAL( INFORMATION)?, /, '')
  place.chomp!
  place.sub!(/CALIF(ORNIA)?/, 'CA')
  place.sub!(/VIRG(INIA)?/, 'VA')
  place.sub!(/TENN(ESSEE)?/, 'TN')
  place.sub!(/, MICH(IGAN)?/, 'MI')
  place.sub!(/, COLO(RADO)?/, ', CO')
  place.sub!(/OHIO/, 'OH')
  place.sub!(/UTAH/, 'UT')
  place.sub!(/, MISS(ISSIPPI)?/, ', MS')
  place.sub!(/, MASS(ACHUSETTS)?/, ', MA')
  place.sub!(/ \d{5}/, '') #zips
  place.sub!(/, ILL(INOIS)?/, ', IL')
  place.sub!(/, ORE(GON)?/, ', OR')
  place.sub!(/, KAN(SAS)?/, ', KS')
  place.sub!(/, NEB(RASKA)?/, ', NE')
  place.sub!(/, MINN(ESOTA)?/, ', MN')
  place.sub!(/, MONT(ANA)?/, ', MT')
  place.sub!(/, IDAHO/, ', ID')
  place.sub!(/, SOUTH CAROLINA/, ', SC')
  place.sub!(/, S C$/, ', SC')
  place.sub!(/, WYO(MING)?/, ', WY')
  place.sub!(/, WIS(CONSIN)?/, ', WI')
  place.sub!(/, WASH(INGTON)?$/, ', WA')
  place.sub!(/, CONN(ECTICUT)?$/, ', CT')
  place.sub!(/, TEX(AS)?$/, ', TX')
  place.sub!(/, NEV(ADA)?$/, ', NV')
  place.sub!(/, IND(IANA)?$/, ', IN')
  place.sub!(/, ARK(ANSAS)?$/, ', AR')
  place.sub!(/, OKLA(HOMA)?$/, ', OK')
  place.sub!(/, FLA$/, ', FL')
  place.sub!(/, FLORIDA$/, ', FL')
  place.sub!(/, ALASKA$/, ', AK')

  place.sub!(/, ([A-Z]) ([A-Z])$/, ', \\1\\2')
  place.sub!(/([A-Z]) ([A-Z]{2})$/, '\\1, \\2')

  if place =~ /^WASHING/
    place = 'WASHINGTON, DC'
  elsif place =~ /^CHICAGO/
    place = 'CHICAGO, IL'
  elsif place =~ /^DENVER/
    place = 'DENVER, CO'
  end

  place.chomp!
  place.sub!(/[,;:\.] *$/, '')
  place.sub!(/([^,]) ([A-Z]{2})$/, '\\1, \\2')

  if place == 'WASHINGTON'
    place = 'WASHINGTON, DC'
  end
  place
end

 
#load the HT we want to work with
source_records = ARGV.shift
`mongo htonly --eval "db.dropDatabase()"`
`mongoimport --db htonly --collection source_records --file #{source_records}`
# Make our report directory if it doesn't already exist
sr_date = source_records.split('_')[1].split('.')[0]
rep_dir = __dir__+"/reports/#{sr_date}_#{Time.now.strftime("%F")}"
Dir.mkdir(rep_dir) unless File.exists? (rep_dir)

#connect Mongoid
Mongoid.load!("config/mongoid.yml", :development)
Mongo::Logger.logger.level = ::Logger::FATAL

#fix our local ids
SourceRecord.all.each do | src |
  src.local_id = src.extract_local_id
  src.save
end

#indexes for htonly
SourceRecord.index(:local_id=>1)
SourceRecord.create_indexes

#load some mappings
contribs = YAML.load_file(__dir__+'/mappings/contributors.yml')
digitizers = YAML.load_file(__dir__+'/mappings/digitizing.yml')
rights = YAML.load_file(__dir__+'/mappings/rights.yml')
sudoc_auth = YAML.load_file(__dir__+'/mappings/sudoc_stems.yml')

# Use traject for a few fields
@extractor = Traject::Indexer.new
@extractor.load_config_file('config/traject_publisher.rb')

summary = { num_bib_records:0, 
            num_digital_objects:0,
            num_monographs:0,
            num_serials:0,
            num_unique_items:0,
            corpus_size:0,
            corpus_percent:0,
            num_missing_sudoc:0,
            num_missing_pubdate:0,
            num_missing_publisher:0,
            num_missing_holding_pubdate:0,
            num_missing_language:0,
            num_monograph_holdings:0,
            num_serial_holdings:0,
            num_rights:0,
            rpt_run_date:DateTime.now.strftime("%Y-%m-%d")}
sudoc_count = 0
item_count = 0
year_cataloged = Hash.new 0 
 
leader = Hash.new 0 

rights_count = Hash.new 0 
digitizing_agent = Hash.new 0
contributors = Hash.new 0
holding_years = Hash.new 0
norm_publisher_counts = Hash.new 0
publisher_counts = Hash.new 0
subject_counts = Hash.new 0
place_of_publication = Hash.new 0
monodupes = Hash.new 0
@compness = Hash.new {|hash, key| hash[key] = Hash.new(0)}
sudoc_stems = Hash.new 0
sudoc_classes = Hash.new 0
year_sudocs = Hash.new {|hash, key| hash[key] = Hash.new(0)}
year_sudoc_classes = Hash.new {|hash, key| hash[key] = Hash.new(0)}
language_counts = Hash.new 0 #using 008. 041 is a headache. todo: ?
sudoc_tree = Hash.new {|hash, key| hash[key] = Hash.new(0)}

languages_out = open(rep_dir+'/languages.tsv', 'w')
monodupes_out = open(rep_dir+'/monodupes.tsv','w')
summjson = open(rep_dir+'/summary.json', 'w')
summ_out = open(rep_dir+'/summary.txt', 'w')
rights_out = open(rep_dir+'/rights.tsv', 'w')
dig_out = open(rep_dir+'/digitizing.tsv', 'w')
contrib_out = open(rep_dir+'/contributors.tsv', 'w')
pub_out = open(rep_dir+'/publisher.tsv', 'w')
normpub_out = open(rep_dir+'/normpublisher.tsv', 'w')
place_out = open(rep_dir+'/place.tsv', 'w')
sub_out = open(rep_dir+'/subject.tsv', 'w')
corp_out = open(rep_dir+'/corp_auth.tsv', 'w')
years_out = open(rep_dir+'/yearpub.tsv', 'w')
sudocs_out = open(rep_dir+'/sudocstems.tsv', 'w')
comp_out = open(rep_dir+'/comprehensiveness.tsv', 'w')
year_sudoc_classes_out = open(rep_dir+'/year_sudocclasses.tsv', 'w')
year_sudocs_out = open(rep_dir+'/year_sudocstems.tsv', 'w')
sudoc_tree_out = open(rep_dir+'/sudoctree.tsv', 'w')

SourceRecord.where(org_code:"miaahdl",
                  deprecated_timestamp:{"$exists":0},
                  in_registry:true).no_timeout.each do | src |
  marc = MARC::Record.new_from_hash(src.source)
  rec = @extractor.map_record(marc)
                  
  year_cataloged[rec['catalog_year']] += 1 

  if rec['language']
    rec['language'].each {|lang| language_counts[lang] += 1 }
  else
    summary[:num_missing_language] += 1
  end

  summary[:num_bib_records] += 1
  leader[src.source['leader'][7]] += 1 

  if src.source['leader'] =~ /^.{7}m/
    summary[:num_monographs] += 1
    monodupes[src.holdings.count] += 1
  elsif src.source['leader'] =~ /^.{7}s/
    summary[:num_serials] += 1
  elsif src.source['leader'] =~ /^.{7}d/
    #PP.pp src.source.to_json
  end

  if src.enum_chrons.count == 0 
    summary[:num_unique_items] += 1
  else
    summary[:num_unique_items] += src.enum_chrons.count
  end

  if rec['publisher']
    rec['publisher'].each do |pub|
      publisher_counts[pub] += 1
      normed = Normalize.corporate(pub, false)
      norm_publisher_counts[normed] += 1
    end
  else 
    summary[:num_missing_publisher] += 1
  end
  if rec['subject']
    rec['subject'].each do | sub |
      subject_counts[sub] += 1
    end
  end
  if rec['place_of_publication']
    rec['place_of_publication'].each do |place|
      place.upcase!
      place.gsub!(/\./,'')
      place_of_publication[normalizePubPlace(place)] += 1
    end 
  end
  if !rec['pub_date']
    summary[:num_missing_pubdate] += 1
  end

  if rec['corp_author']
    #PP.pp rec['corp_author']
    #PP.pp Normalize.corporate(rec['corp_author'].map{ |sf| Normalize.corporate(sf)}.join(' '), false)
  end

  if src.sudocs.count == 0
    summary[:num_missing_sudoc] += 1
  end
  src.sudocs.each do |sudoc|
    m = /^(?<stem>[A-Z]+ ?[0-9]+)[\.: ]/.match(sudoc.upcase)
    if !m.nil?
      stem = m['stem'].gsub(/([A-Z]+)([0-9]+)/, '\1 \2') #missing whitespace
      sudoc_tree[stem.split(' ')[0]][stem] += 1
      sudoc_stems[stem] += 1
      sudoc_classes[stem.split(' ')[0]] += 1
      #we'll add this stem for every pub year in the holdings
      src.holdings.each do |ec, holdings|
        holdings.each do |hold|
          year_sudoc_classes[hold[:y]][m['stem'].split(' ')[0]] += 1
          year_sudocs[hold[:y]][m['stem']] += 1
        end
      end

    end
  end

  #holdings level counts
  src.holdings.each do |ec, holdings|
    holdings.each do |hold|
      summary[:num_digital_objects] += 1
      if rights.keys.include? hold[:r]
        rights_count[rights[hold[:r]]] += 1
      else
        rights_count[hold[:r]] += 1
      end
      digitizing_agent[digitizers[hold[:s]]] += 1
      contributors[contribs[hold[:c].downcase]] += 1
      holding_years[hold[:y]] += 1
      if hold[:y].nil? or hold[:y] == ''
        summary[:num_missing_holding_pubdate] += 1 
      end
      if src.source['leader'] =~ /^.{7}m/
        summary[:num_monograph_holdings] += 1
        monodupes[src.holdings.count] += 1
      elsif src.source['leader'] =~ /^.{7}s/
        summary[:num_serial_holdings] += 1
      elsif src.source['leader'] =~ /^.{7}d/
        #PP.pp src.source.to_json
      end

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

# get some basic details of the Registry for comprehensiveness purposes
# refactor!!!!
Mongoid.load!("config/mongoid.yml", :production)
summary[:corpus_size] = RegistryRecord.where(deprecated_timestamp:{"$exists":0}).count
summary[:corpus_percent] = summary[:num_unique_items].to_f / summary[:corpus_size].to_f * 100.0
setComprehensiveness("Congressional Record")
setComprehensiveness("Statistical Abstract")
setComprehensiveness("United States Reports")
setComprehensiveness("Foreign Relations")
setComprehensiveness("Congressional Serial Set")
setComprehensiveness("Civil Rights Commission")
setComprehensiveness("Economic Report Of The President")

summary[:num_rights] = rights_count.keys.count
summjson.puts summary.to_json
summ_out.puts "# of Bibliographic Records: #{summary[:num_bib_records]}"
summ_out.puts "#{summary[:num_monographs]} monograph records. #{summary[:num_serials]} serial records."
summ_out.puts "# of unique items represented in the Registry: #{summary[:num_unique_items]}"
summ_out.puts "# of digital objects (974): #{summary[:num_digital_objects]}"

language_counts.sort_by {|lang, cnt| cnt}.reverse
  .each {|lang, cnt| languages_out.puts "#{lang}\t#{cnt}"}
sudoc_stems.sort_by {|sudoc, cnt| cnt}.reverse
  .each {|sudoc, cnt| sudocs_out.puts "#{sudoc}\t#{cnt}\t#{sudoc_auth[sudoc.split(' ')[0]]}"}
@compness.each do | series, line | 
  comp_out.puts [series.to_s, line[:ht], line[:corpus], (line[:ht].to_f / line[:corpus] * 100.0).round(2)].join("\t")
end
monodupes.sort_by {|dupe_count, cnt| dupe_count}
  .each {|dupe_count, cnt| monodupes_out.puts "#{dupe_count}\t#{cnt}"}
rights_count.sort_by {|r, cnt| cnt}.reverse
    .each {|r,cnt| rights_out.puts "#{r}\t#{cnt}"}
contributors.sort_by {|c, cnt| cnt}.reverse
    .each {|c,cnt| contrib_out.puts "#{c}\t#{cnt}"}
digitizing_agent.sort_by {|s, cnt| cnt}.reverse
    .each {|s,cnt| dig_out.puts "#{s}\t#{cnt}"}
#eliminate questionable publishing years
sorted_years = holding_years.select {|y, cnt| y.to_s.to_i >= 1789 && y.to_s.to_i <= 2016 }
    .sort_by {|y, cnt| y}.map{|tuple| tuple[0]}
sorted_years.each {|y| years_out.puts "#{y}\t#{holding_years[y]}"}

#sudoc_tree_out.puts ['SuDoc', 'Parent', '#'].join("\t")
sudoc_tree.each do | sclass, subs | 
  sudoc_tree_out.puts [sclass, 'SuDocs', '0'].join("\t")
  subs.each do | sub, cnt |
    sudoc_tree_out.puts [sub, sclass, cnt].join("\t")
  end
end

#header for year_sudocs is [year. stem1, stem2...]
stems_sorted = sudoc_stems.sort_by {|sudoc, cnt| cnt}.reverse.map {|tuple| tuple[0]}
ys_header = ['Year'] + stems_sorted
#converting hash of hashes into tsv format, rows ordered by year, col ordered by stem
year_sudocs_out.puts ys_header.join("\t")
sorted_years.each {|y| year_sudocs_out.puts year_sudocs[y].values_at(*stems_sorted).map{|s| s ? s : 0}.unshift(y).join("\t")}

#header for year_sudoc_classes is [year, class1, class2...]
classes_sorted = sudoc_classes.sort_by {|sclass, cnt| cnt}.reverse.map {|tuple| tuple[0]}
ys_header = ['Year'] + classes_sorted
#converting hash of hashes into tsv format, rows ordered by year, col ordered by class
year_sudoc_classes_out.puts ys_header.join("\t")
sorted_years.each {|y| year_sudoc_classes_out.puts year_sudoc_classes[y].values_at(*classes_sorted)
                   .map{|s| s ? s : 0}
                   .unshift(y).join("\t")}


norm_publisher_counts.sort_by {|k,v| v}.reverse
  .each {|pub,cnt| normpub_out.puts "#{pub}\t#{cnt}"}
publisher_counts.sort_by {|k,v| v}.reverse
  .each {|pub,cnt| pub_out.puts "#{pub}\t#{cnt}"}
place_of_publication.sort_by{|k,v| v}.reverse
  .each {|place,cnt| place_out.puts "#{place}\t#{cnt}"}
subject_counts.sort_by {|k,v| v}.reverse
  .each {|sub,cnt| sub_out.puts "#{sub}\t#{cnt}"}

