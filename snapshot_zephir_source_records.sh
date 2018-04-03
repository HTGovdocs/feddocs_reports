DATE=$(date +\%Y\%m\%d)
mongoexport -d htgd -c source_records --query '{org_code:\"miaahdl\"}' -o /l1/govdocs/reports/data/ht_$DATE.json
mongoimport -d zephir_$(date +\%Y\%m\%d) -c source_records -f /l1/govdocs/reports/data/ht_$DATE.json
