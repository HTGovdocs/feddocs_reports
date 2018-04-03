D=$(date +\%Y-\%m-\%d)
snapshot_zephir_source_records.sh
bundle exec ruby collection_profile_report.rb $D
bundle exec ruby stat_overview_report.rb
