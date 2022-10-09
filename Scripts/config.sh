
download_working_dir=download-working
download_dir=download
checksum_file=download-checksum.txt
seen_file=download-seen.txt



url_meta() {
  echo "https://data.rada.gov.ua/ogd/zal/stenogram/skl$1/meta.xml"
  }

xpath() {
  java -cp /usr/share/java/saxon.jar net.sf.saxon.Query -xi:off \!method=adaptive -s:$1 -qs:"$2" | sed 's/^"//;s/"$//'
}

