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
to_field "publisher",         extract_marc("260b:264b")

#place of publication
to_field "place_of_publication",   extract_marc("260a:264|1*|abc", :trim_punctuation => true)

to_field "pub_date",            marc_publication_date

#subject
to_field "subject",           extract_marc("651")#"600:610:611:650:651")

#corporate author
to_field "author",            extract_marc("100abcdgqu:110abcdgnu:111acdegjnqu:700abcdegqu:710abcdegnu:711acdegjnqu")
to_field "corp_author", extract_marc("110ab", :separator => nil)

#catalog_year
to_field "catalog_year", extract_marc("008[0-1]") 

#language
to_field "language", marc_languages("008[35-37]:041a:041d:041e:041j") 

#title
to_field "title",       extract_marc("245a", :trim_punctuation => true)

