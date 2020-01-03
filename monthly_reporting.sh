D=$(date +\%Y-\%m-\%d)
./snapshot_zephir_source_records.sh
bundle exec ruby collection_profile_report.rb $D
bundle exec ruby stat_overview_report.rb


mkdir /htapps-dev/jstever.apps/usdocs_registry/public/assets/$D
cp reports/num*.csv /htapps-dev/jstever.apps/usdocs_registry/public/assets/stats/
cp reports/${D}_${D}/* /htapps-dev/jstever.apps/usdocs_registry/public/assets/$D
