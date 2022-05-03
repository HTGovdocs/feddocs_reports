1. Mongo exports all source records originating from HTDL.
2. Reimports them into the mongodb as database `zephir_<yyyymmdd>`
3. Runs the collection_profile_report.rb with todays date: 
  * has mappings for contributors, digitizers, rights, and sudoc stems (none are being updated)
  * builds a summary for `zephir_<yyyymmdd>`
  * num_unique_items is based on enum_chrons (not HTDL items)
  * num_digital_objects is the HTDL items
  * Gets comprehensiveness data for the entire corpus and for selected series
  * outputs:
    * summary.json and summary.txt
    * languages.tsv
    * monodupes.tsv
    * rights.tsv
    * digitizing.tsv
    * contributors.tsv
    * publisher.tsv
    * normpublisher.tsv
    * place.tsv
    * subject.tsv
    * corp_auth.tsv
    * yearpub.tsv
    * sudocstems.tsv
    * comprehensiveness.tsv
    * year_sudocclasses.tsv
    * year_sudocstems.tsv
    * sudoctree.tsv
4. Runs `stat_overview_report.rb`
  Compiles a list of deprecated source record ids from the existing database.
  Foreach monthly snapshot database it compiles num_full_text, num_not_full_text, num_monos, num_serials, num_undefined and sudoc class counts, *skipping sources that have since been deprecated.*
  Output:
    * num_bibs.csv
    * num_dig.csv
    * num_sudocs.csv

5. Copies reports/num_*.csv to htapps-dev/jstever.apps/usdocs_registry/public/assets/stats/

6. Copies reports/<date>_<date>/* to htapps-dev/jstever.apps/usdocs_registry/public/assets/<date>
