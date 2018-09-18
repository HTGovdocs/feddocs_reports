DATE=$(date +\%Y-\%m-\%d)
mongoexport --quiet -d htgd -c source_records --query '{org_code:"miaahdl"}' -o /l1/govdocs/reports/data/ht_$DATE.json
mongoimport --quiet -d zephir_$(date +\%Y\%m\%d) -c source_records --file /l1/govdocs/reports/data/ht_$DATE.json
gzip /l1/govdocs/reports/data/ht_$DATE.json
