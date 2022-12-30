#!/bin/bash

#D=`dirname $0`
#cd $D

pid=$$

CONFIG_FILE="config.sh"
TERM=
ID=
OUTPUT_DIR=



usage() {
  echo -e "Usage: $0 .................... -c CONFIG_FILE" 1>&2
  exit 1
}

while getopts  ':t:d:c:O:'  opt; do
  case "$opt" in
    'c')
      CONFIG_FILE=$OPTARG
      ;;
    't')
      TERM=$OPTARG
      ;;
    'd')
      ID=$OPTARG
      ;;
    'O')
      OUTPUT_DIR=$OPTARG
      ;;
    *)
      usage
  esac
done


set -o allexport
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi
set +o allexport


working_dir=$OUTPUT_DIR/$download_working_dir/$ID
steno_archive=$working_dir/skl${TERM}stenogram_txt.zip
steno_meta_archive=$working_dir/skl${TERM}stenogram_ses.zip
steno_dir=$working_dir/skl${TERM}stenogram_txt
steno_meta_dir=$working_dir/skl${TERM}stenogram_ses
out_dir=$OUTPUT_DIR/$download_dir/$ID



function log {
  str=`date +"%Y-%m-%d %T"`"\t$@"
  echo -e "$str"
}

function add_file(){
  md5sum=`md5sum $steno_dir/$1 |cut -f1 -d' '`
  date=`echo $1 | sed 's/-.*$//;s/.htm//'`
  number=`echo $1 | sed 's/\.htm$//' |sed '/^[0-9]*$/s/$/-0/'|sed 's/^.*-//'`
  line=`iconv -f ISO-8859-1 -t UTF-8//TRANSLIT $steno_meta_dir/*|grep -P "$date\t$TERM\t[0-9]+\t$number\t.*html"|sort -r|head -n1`
  session=`echo -n "$line" |cut -f3`
  meeting_type=`echo -n "$line" |cut -f5|sed 's/^b//'|sed 's/_yellow/ regular/;s/_orange/ extraordinary/;s/_[a-z]*//g'|sed 's/^ //'`
  url_source_html=`echo -n "$line" |cut -f6`
  echo -e "$ID\t$md5sum\t$TERM\t$session\t$meeting_type\t$1\t$url_source_html" >> $OUTPUT_DIR/$seen_file ; \
  mv $steno_dir/$1 $out_dir/$1
}

log "STARTED: $pid"
log "CONFIG FILE: $CONFIG_FILE"


mkdir -p $working_dir
touch $OUTPUT_DIR/$checksum_file
touch $OUTPUT_DIR/$seen_file


meta_xml_path=$working_dir/skl${TERM}meta.xml


log "downloading meta from term $TERM"
wget -q `url_meta $TERM` -O $meta_xml_path ;\
META=`xpath $meta_xml_path '//item[./name/text() = "stenogram_txt"]/concat(../opendata,./path,./name,".",./archived,"&#9;",./checksum,"&#9;",./pubDate,"&#9;",./size)'`

if grep -q `echo "$META"|cut -f2` $OUTPUT_DIR/$checksum_file
then
  exit 1
else
  STENO_META=`xpath $meta_xml_path '//item[./name/text() = "stenogram_ses"]/concat(../opendata,./path,./name,".",./archived,"&#9;",./checksum,"&#9;",./pubDate,"&#9;",./size)'`
  log "NEW DATA IN TERM $TERM"; \
  echo -e "$ID\t$META" >> $OUTPUT_DIR/$checksum_file ; \
  wget -q `echo "$META"|cut -f1` -O $steno_archive ;\
  wget -q `echo "$STENO_META"|cut -f1` -O $steno_meta_archive ;\
  log "extracting $steno_archive"
  unzip -q $steno_archive -d $steno_dir
  log "extracting $steno_meta_archive"
  unzip -q $steno_meta_archive -d $steno_meta_dir
  log "checking new files"

  mkdir -p $out_dir
  for file in `ls $steno_dir`
  do
    if grep -q $file $OUTPUT_DIR/$checksum_file
    then
      $md5sum=`md5sum $steno_dir/$file |cut -f1 -d' '`
      if ! grep -q '$md5sum\t$file' $OUTPUT_DIR/$checksum_file
      then
        log "file changed: $file"
        add_file $file
      fi
    else
      log "new file: $file"
      add_file $file
    fi
  done
fi


