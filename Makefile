.DEFAULT_GOAL := help

s = java -jar /usr/share/java/saxon.jar
xpath = xargs -I % java -cp /usr/share/java/saxon.jar net.sf.saxon.Query -xi:off \!method=adaptive -s:% -qs:


##$TERMS## Terms that are processed.
TERMS = 7 8 9
##$DATADIR## Folder with country corpus folders. Default value is 'Data'.
DATADIR = Data

DATE := $(shell sh -c 'date +"%Y%m%dT%H%M%S"')

###### steno:

.PHONY: $(download-NN) download
download-NN = $(addprefix download-, $(TERMS))
## download ## downloads new data from all terms defined in variable TERM
download: $(download-NN)
## download-NN ## Downloads new data from term NN
$(download-NN): download-%:
	./Scripts/download.sh -t $* -d $(DATE) -O $(DATADIR) -c Scripts/config.sh || echo "$@: NO NEW DATA"



DOWNLOAD_DATA_ALL := $(shell ls $(DATADIR)/download)
DOWNLOAD_DATA_LAST := $(shell ls $(DATADIR)/download | grep -v '_' | sort -r | head -n1)
TEI-TEXT_DATA_ALL := $(shell ls $(DATADIR)/tei-text)
TEI-TEXT_DATA_LAST := $(shell ls $(DATADIR)/tei-text | grep -v '_' | sort -r | head -n1)

# PROCESS_SUBSET := --process-subset "20[12][912]...."
# PROCESS_SUBSET := --process-subset "20[12].....-?.?"
#PROCESS_SUBSET := --process-subset "20[12].02.."
#PROCESS_SUBSET := --process-subset "20220223"
#PROCESS_SUBSET := --process-subset "20[12].02..-?.?"

.PHONY: $(html2tei-text-RUN) html2tei-text
html2tei-text-RUN-ALL = $(addprefix html2tei-text-, $(DOWNLOAD_DATA_ALL))
html2tei-text-RUN-LAST = $(addprefix html2tei-text-, $(DOWNLOAD_DATA_LAST))
## html2tei-text ## html2tei-texts
html2tei-text: html2tei-text-last
html2tei-text-last: $(html2tei-text-RUN-LAST)
html2tei-text-all: $(html2tei-text-RUN-ALL)

## html2tei-text-RUN ##
$(html2tei-text-RUN-ALL): html2tei-text-%:
	./Scripts/html2tei-text.pl --id $* \
	                           --data-dir "$(DATADIR)" \
	                           --config Scripts/config.sh \
	                           --file-id "ParlaMint-UA" \
	                           $(PROCESS_SUBSET)

link-speakers2tei-text-RUN-ALL = $(addprefix link-speakers2tei-text-, $(TEI-TEXT_DATA_ALL))
link-speakers2tei-text-RUN-LAST = $(addprefix link-speakers2tei-text-, $(TEI-TEXT_DATA_LAST))
## link-speakers2tei-text ## link-speakers2tei-texts
link-speakers2tei-text: link-speakers2tei-text-last
link-speakers2tei-text-last: $(link-speakers2tei-text-RUN-LAST)
link-speakers2tei-text-all: $(link-speakers2tei-text-RUN-ALL)

## link-speakers2tei-text-RUN ##
$(link-speakers2tei-text-RUN-ALL): link-speakers2tei-text-%:
	mkdir -p Data/tei-text-speakers/$*/
	$s -xsl:Scripts/link-speakers2tei-text.xsl \
	   -o:Data/tei-text-speakers/$*/ParlaMint-UA.xml \
	      speaker-links="../Data/tei-particDesc-preprocess/$(DOWNLOAD_META_DATA_LAST)/mp-data-aliases.tsv" \
	      in-dir="../Data/tei-text/$*/" \
	      out-dir="../Data/tei-text-speakers/$*/" \
	      Data/tei-text/$*/ParlaMint-UA.xml








###### metadata:
.PHONY: $(download-meta-NN) download-meta
download-meta-NN = $(addprefix download-meta-, $(TERMS))
## download-meta ## metadata from all terms defined in variable TERM
download-meta: $(download-meta-NN)
	wget https://data.rada.gov.ua/ogd/zal/mps/mps-trans_fr.csv -O $(DATADIR)/download-meta/$(DATE)/ogd_zal_mps_mps-trans_fr.csv
## download-meta-NN ## Downloads all metadata from term NN
$(download-meta-NN): download-meta-%:
	mkdir -p $(DATADIR)/download-meta/$(DATE)
	wget https://data.rada.gov.ua/ogd/mps/skl$*/mps-data.xml -O $(DATADIR)/download-meta/$(DATE)/ogd_mps_skl$*_mps-data.xml
	$(eval SKL := $(shell echo $* | sed "s/^/0/"| sed "s/\(..\)$$/\1/" ))
	wget https://data.rada.gov.ua/ogd/mps/skl$*/mps$(SKL)-data.xml -O $(DATADIR)/download-meta/$(DATE)/ogd_mps_skl$*_mps$(SKL)-data.xml

DOWNLOAD_META_DATA_LAST := $(shell ls $(DATADIR)/download-meta | grep -v '_' | sort -r | head -n1)
tei-particDesc-RUN-LAST = $(addprefix tei-particDesc-, $(DOWNLOAD_META_DATA_LAST))
DOWNLOAD_META_DATA_LAST_TERMS = $(shell ls $(DATADIR)/download-meta/$(DOWNLOAD_META_DATA_LAST)/ogd_mps_skl*_mps-data.xml|sed "s/^.*skl\([0-9]*\)_.*$$/\1/"|tr "\n" " "|sed "s/ *$$//")

tei-particDesc: $(tei-particDesc-RUN-LAST)
$(tei-particDesc-RUN-LAST): tei-particDesc-%: tei-particDesc-preprocess-%
	mkdir -p $(DATADIR)/tei-particDesc-working/$*
	mkdir -p $(DATADIR)/tei-particDesc/$*
	@echo "TODO: PROCESS META $*"
	@echo "input files:"
	@find $(DATADIR)/tei-particDesc-preprocess/$* -type f|sed 's/^/\t/'
	echo "<?xml version=\"1.0\" ?>\n<root/>" | \
	  $s -s:- -xsl:Scripts/metadata-preprocess.xsl \
	      terms="$(DOWNLOAD_META_DATA_LAST_TERMS)" \
	      in-dir=../Data/tei-particDesc-preprocess/$*/ \
	      out-dir=Data/tei-particDesc-preprocess/$*/





tei-particDesc-preprocess-RUN-LAST = $(addprefix tei-particDesc-preprocess-, $(DOWNLOAD_META_DATA_LAST))
tei-particDesc-preprocess: $(tei-particDesc-preprocess-RUN-LAST)
$(tei-particDesc-preprocess-RUN-LAST): tei-particDesc-preprocess-%:
	mkdir -p $(DATADIR)/tei-particDesc-preprocess/$*
	cp $(DATADIR)/download-meta/$*/*.csv $(DATADIR)/tei-particDesc-preprocess/$*/
	for FILE in `ls $(DATADIR)/download-meta/$* | grep '.xml$$'`; do \
	  xmllint --format $(DATADIR)/download-meta/$*/$${FILE} \
	    | perl -Mopen=locale -pe 's/&#x([\da-f]+);/chr hex $$1/gie' \
	    > $(DATADIR)/tei-particDesc-preprocess/$*/$${FILE}; \
	done







###### other:
create-metadata-sample:
	rm -rf SampleMetaData/*
	mkdir -p SampleMetaData/01-source
	mkdir -p SampleMetaData/02-preprocess
	find $(DATADIR)/tei-particDesc-preprocess/$(DOWNLOAD_META_DATA_LAST)/ -name "ogd_mps_skl*_mps*-data.xml" | xargs -I {} cp {} SampleMetaData/01-source/
	find $(DATADIR)/tei-particDesc-preprocess/$(DOWNLOAD_META_DATA_LAST)/ -name "mp-data*.*"|grep -v "mp-data-stats" | xargs -I {} cp {} SampleMetaData/02-preprocess/
	find $(DATADIR)/tei-particDesc-preprocess/$(DOWNLOAD_META_DATA_LAST)/ -name "mp-data-stats*.*" | xargs -I {} cp {} DataStats/


create-february-sample:
	rm -rf SampleData/*
	mkdir -p SampleData/01-htm
	mkdir -p SampleData/02-tei-text
	mkdir -p SampleData/03-tei-text-speakers
	ls $(DATADIR)/download/$(TEI-TEXT_DATA_LAST)/20??02??*.htm | xargs -I {} cp {} SampleData/01-htm/
	ls $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ParlaMint-UA_20??-02-??*.xml | xargs -I {} cp {} SampleData/02-tei-text/
	ls $(DATADIR)/tei-text-speakers/$(TEI-TEXT_DATA_LAST)/ParlaMint-UA_20??-02-??*.xml | xargs -I {} cp {} SampleData/03-tei-text-speakers/

create-all-stats:
	#rm -rf DataStats/*
	mkdir -p DataStats
	find $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o '<note>[^<]*</note>'|sort|uniq -c|sort -nr > DataStats/note_cnt.log
	find $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o '<note type="speaker">[^<]*</note>'|sed "s/^[^>]*>//;s/<.*$$//"|sort|uniq -c|sort -nr > DataStats/note_speaker_cnt.log
	find $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o '<u [^>]*>'|sed 's/^.*who="//;s/".*$$//'|sort|uniq -c|sort -nr > DataStats/u_who_cnt.log
	find $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o '<u [^>]*>'|sed 's/^.*who="//;s/" .*ana="/\t/;s/".*$$//'|sort|uniq -c|sort -nr > DataStats/u_who_ana_cnt.log
	find $(DATADIR)/tei-text-speakers/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o '<u [^>]*>'|sed 's/^.*who="//;s/" .*ana="/\t/;s/".*$$//'|sort|uniq -c|sort -nr > DataStats/u_whoref_ana_cnt.log
	find $(DATADIR)/tei-text-speakers/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o 'who="[^#"]*"'|sed 's/^who="\(.*\)"/\1/'|sort|uniq -c|sort -nr > DataStats/u_who-no-attrib_cnt.log
	find $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o '<seg>[^<]*</seg>'|sort|uniq -c|grep -v "^ *1 <seg" |sort -nr > DataStats/seg_non_uniq.log
	find $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   tr "\n" " "|sed "s/\(<[^<]*>[^>]*<desc[^>]*>[^<]*\)/\n\1\n\n\n/g"|\
	   grep '<desc'|sed -E 's/^<([^ ]*).*(type|reason)="([^"]*)".*<desc[^>]*>/\1\t\3\t/'|\
	   sort|uniq -c|sort -nr > DataStats/incident_ana_cnt.log

search-text:
	mkdir -p DataSearchResults
	grep -rnioP 'Мініст[\p{Lu}\p{Lt}\p{Ll}]*[^\.]{0,20}?(?:\s+\p{Lu}[\p{Lu}\p{Lt}\p{Ll}]*){3}' Data/tei-text/$(TEI-TEXT_DATA_LAST)/\
	  |sed "s/^.*UA_//;s/-..-m..xml:[0-9]*:/\t/"|sed 's/"//g'|sort|uniq > DataSearchResults/minister_name_context.tsv



######---------------
DEV-tei-text-stats-RUN-LAST = $(addprefix tei-text-stats-, $(TEI-TEXT_DATA_LAST))
DEV-tei-text-stats: $(DEV-tei-text-stats-RUN-LAST)
$(DEV-tei-text-stats-RUN-LAST): tei-text-stats-%:
	echo "statistics of $*"
	mkdir -p $(DATADIR)/tei-text-stats/$*/
	find $(DATADIR)/tei-text/$*/ -type f |xargs cat|\
	   grep -o '<note>[^<]*</note>'|sort|uniq -c|sort -nr|nl > $(DATADIR)/tei-text-stats/$*/note_cnt.log
	find $(DATADIR)/tei-text/$*/ -type f |xargs cat|\
	   grep -o '<note type="time">[^<]*</note>'|sort|uniq -c|sort -nr|nl > $(DATADIR)/tei-text-stats/$*/note_time_cnt.log
	find $(DATADIR)/tei-text/$*/ -type f |xargs cat|\
	   grep -o '<seg>[^<]*</seg>'|sort|uniq -c|grep -v "^ *1 <seg" |sort -nr|nl > $(DATADIR)/tei-text-stats/$*/seg_non_uniq.log


TEI-TEXT_DATA_LAST-CHANGE := $(shell stat $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST) | grep 'Modify'|sed 's/^Modify: //;s/\..*$$//'|tr " " "T"|sed "s/[-:]//g")
TEI-TEXT_DATA_LAST-BACKUP := $(shell ls DevDataBackup/tei-text/$(TEI-TEXT_DATA_LAST) | grep -v '_' | sort -r | head -n1)
DEV-backup-last-tei-text:
	echo "$(TEI-TEXT_DATA_LAST-CHANGE)"
	mkdir -p DevDataBackup/tei-text/$(TEI-TEXT_DATA_LAST)/$(TEI-TEXT_DATA_LAST-CHANGE)/
	cp $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/* DevDataBackup/tei-text/$(TEI-TEXT_DATA_LAST)/$(TEI-TEXT_DATA_LAST-CHANGE)/
DEV-recent-changes-tei-text:
	meld DevDataBackup/tei-text/$(TEI-TEXT_DATA_LAST)/$(TEI-TEXT_DATA_LAST-BACKUP)/ $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/

######---------------
TEST_DOWNDATA_ALL := $(shell ls FileLists| sed "s/.fl$$//")
DEV-prepare-test-downdata = $(addprefix DEV-prepare-test-downdata-, $(TEST_DOWNDATA_ALL))
## DEV-prepare-test-downdata ## DEV-prepare-test-data
## DEV-prepare-test-downdata- ##
$(DEV-prepare-test-downdata): DEV-prepare-test-downdata-%:
	mkdir -p $(DATADIR)/download/_$*/
	rm -f $(DATADIR)/download/_$*/*
	cat FileLists/$*.fl|xargs -I {} cp -f $(DATADIR)/download/$(DOWNLOAD_DATA_LAST)/{} $(DATADIR)/download/_$*/



######---------------

_help-intro:
	@echo "\n "

_help-variables:
	@echo "\033[1m\033[32mVARIABLES:\033[0m"
	@echo "Variable VAR with value 'value' can be set when calling target TARGET in $(MAKEFILE_LIST): make VAR=value TARGET"
	@grep -E '^## *\$$[a-zA-Z_-]*.*?##.*$$' $(MAKEFILE_LIST) |sed 's/^## *\$$/##/'| awk 'BEGIN {FS = " *## *"}; {printf "\033[1m%s\033[0m\033[36m%-18s\033[0m %s\n", $$4, $$2, $$3}'

_help-targets:
	@echo "\033[1m\033[32mTARGETS:\033[0m"
	@grep -E '^## *[a-zA-Z_-]+.*?##.*$$|^####' $(MAKEFILE_LIST) | awk 'BEGIN {FS = " *## *"}; {printf "\033[1m%s\033[0m\033[36m%-25s\033[0m %s\n", $$4, $$2, $$3}'


.PHONY: help
## help ## print this help
help: _help-intro _help-variables _help-targets

clean:
	rm -r $(DATADIR)

