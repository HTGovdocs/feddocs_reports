require 'pp'
require 'library_stdnums'


# To have access to various built-in logic
# for pulling things out of MARC21, like `marc_languages`
require 'traject/macros/marc21_semantics'
extend  Traject::Macros::Marc21Semantics

# To have access to the traject marc format/carrier classifier
require 'traject/macros/marc_format_classifier'
extend Traject::Macros::MarcFormats

settings do
  #provide "solr.url", "http://solr-sdr-usfeddocs-dev:9032/usfeddocs/collection1"
  provide "reader_class_name", "Traject::NDJReader"
  provide "marc_source.type", "json"
end

#publisher
to_field "publisher",         extract_marc("260b")

#place of publication
to_field "place_of_publication",   extract_marc("260a:264|1*|abc", :trim_punctuation => true)

#subject
to_field "subject",           extract_marc("600:610:611:630:650:651avxyz:653aa:654abcvyz:655abcvxyz:690abcdxyz:691abxyz:692abxyz:693abxyz:656akvxyz:657avxyz:652axyz:658abcd")

#corporate author
to_field "corp_author", extract_marc("110ab")

#catalog_year
to_field "catalog_year", extract_marc("008[0-1]") 
 
