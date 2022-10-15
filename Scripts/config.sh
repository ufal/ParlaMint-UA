#!/bin/bash

old_variables=`declare -p|sed -n "s/=.*$/\n/;s/^declare -. //"`

download_working_dir=download-working
download_dir=download
checksum_file=download-checksum.txt
seen_file=download-seen.txt
html2tei_text=tei-text


url_source_html(){
  echo "https://data.rada.gov.ua/ogd/zal/stenogram/skl$1/$2"
}

url_meta() {
  echo "https://data.rada.gov.ua/ogd/zal/stenogram/skl$1/meta.xml"
  }

xpath() {
  java -cp /usr/share/java/saxon.jar net.sf.saxon.Query -xi:off \!method=adaptive -s:$1 -qs:"$2" | sed 's/^"//;s/"$//'
}


variables=`declare -p|sed -n "/^declare -. /s/$/\n/p"`
new_variables=`echo "$variables" | sed -n "s/=.*$/\n/;s/^declare -. //p"`

added_variables=`echo -e "$old_variables\n$new_variables" | sort | uniq -c | sed -n "s/^\s*1\s*//p"| grep -v "'"|tr "\n" "|"`

if [[ "$1" == 'list' ]]
then
  echo "$variables" |grep -P "($added_variables)="| sed "s/^declare -. //"
fi
