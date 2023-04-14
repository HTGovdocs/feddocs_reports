# Copy reports files to web dir
reports="reports/20*"
web_dir="/htapps/www/files/feddocs_stats"
cp -R ${reports} ${web_dir}/

# Turn paths into hrefs links and put in link_paths.html
ls -w1 -d ${reports}/* |
    sort -r |
    sed -r 's!reports/!https://www.hathitrust.org/files/feddocs_stats/!g' |
    sed -r 's!(.+)!<a href="\1">\1</a><br/>!g' > ${web_dir}/link_paths.html
