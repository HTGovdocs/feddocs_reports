D=$(date +\%Y-\%m-\%d)
# export source records with org code "miaahdl" for future tracking (data/ht_YYYY-mm-dd.json)
# import as new database "zephir_<YYYYmmdd>
./snapshot_zephir_source_records.sh

# bunch of counts for the collection profile based on the above snapshot. Not backward looking
# Generates a dozen *.tsv files, one for each field. 
bundle exec ruby collection_profile_report.rb $D

# Monthly totals for num_bibs, num_dig, and num_sudocs.
# We used to recalculate historical numbers, but now we just do a monthly append
# DEV-263
bundle exec ruby stat_overview_report.rb

# Move the reports to the dev site. This gets us 80% of the way to deploy
mkdir /htapps-dev/jstever.apps/usdocs_registry/public/assets/$D
cp reports/num*.csv /htapps-dev/jstever.apps/usdocs_registry/public/assets/stats/
cp reports/${D}_${D}/* /htapps-dev/jstever.apps/usdocs_registry/public/assets/$D

# Manual commit/push then pull and puma restart in prod
