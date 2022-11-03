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








###### metadata:
.PHONY: $(download-meta-NN) download-meta
download-meta-NN = $(addprefix download-meta-, $(TERMS))
## download-meta ## metadata from all terms defined in variable TERM
download-meta: $(download-meta-NN)
## download-meta-NN ## Downloads all metadata from term NN
$(download-meta-NN): download-meta-%:
	mkdir -p $(DATADIR)/download-meta/$(DATE)
	wget https://data.rada.gov.ua/ogd/mps/skl$*/mps-data.xml -O $(DATADIR)/download-meta/$(DATE)/ogd_mps_skl$*_mps-data.xml

DOWNLOAD_META_DATA_LAST := $(shell ls $(DATADIR)/download-meta | grep -v '_' | sort -r | head -n1)
tei-particDesc-RUN-LAST = $(addprefix tei-particDesc-, $(DOWNLOAD_META_DATA_LAST))
tei-particDesc: $(tei-particDesc-RUN-LAST)
$(tei-particDesc-RUN-LAST): tei-particDesc-%: tei-particDesc-preprocess-%
	@echo "TODO: PROCESS META $*"

tei-particDesc-preprocess-RUN-LAST = $(addprefix tei-particDesc-preprocess-, $(DOWNLOAD_META_DATA_LAST))
tei-particDesc-preprocess: $(tei-particDesc-preprocess-RUN-LAST)
$(tei-particDesc-preprocess-RUN-LAST): tei-particDesc-preprocess-%:
	mkdir -p $(DATADIR)/tei-particDesc-preprocess/$*
	for FILE in `ls $(DATADIR)/download-meta/$* | grep '.xml$$'`; do \
	  xmllint --format $(DATADIR)/download-meta/$*/$${FILE} \
	    | perl -Mopen=locale -pe 's/&#x([\da-f]+);/chr hex $$1/gie' \
	    > $(DATADIR)/tei-particDesc-preprocess/$*/$${FILE}; \
	done
	mkdir -p $(DATADIR)/tei-particDesc-working/$*
	mkdir -p $(DATADIR)/tei-particDesc/$*


tei-particDesc-preprocess_LAST := $(shell ls $(DATADIR)/tei-particDesc-preprocess | grep -v '_' | sort -r | head -n1)
tei-particDesc-preprocess_LAST-TERMS := $(shell ls $(DATADIR)/tei-particDesc-preprocess/$(tei-particDesc-preprocess_LAST) | sed 's/^.*skl//;s/_mps-data.xml$$//' | sort|uniq)
tei-particDesc-RUN-LAST = $(addprefix tei-particDesc-, $(tei-particDesc-preprocess_LAST))
tei-particDesc: $(tei-particDesc-RUN-LAST)
$(tei-particDesc-RUN-LAST): tei-particDesc-%:
	echo "TODO: process each term $(particDesc)"
	echo "      merge term info"








###### other:
create-february-sample:
	rm -rf SampleData/*
	mkdir -p SampleData/01-htm
	mkdir -p SampleData/02-tei-text
	ls $(DATADIR)/download/$(TEI-TEXT_DATA_LAST)/20??02??*.htm | xargs -I {} cp {} SampleData/01-htm/
	ls $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ParlaMint-UA_20??-02-??*.xml | xargs -I {} cp {} SampleData/02-tei-text/

create-all-stats:
	rm -rf DataStats/*
	mkdir -p DataStats
	find $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o '<note>[^<]*</note>'|sort|uniq -c|sort -nr > DataStats/note_cnt.log
	find $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o '<note type="speaker">[^<]*</note>'|sed "s/^[^>]*>//;s/<.*$$//"|sort|uniq -c|sort -r > DataStats/note_speaker_cnt.log
	find $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o '<u [^>]*>'|sed 's/^.*who="//;s/".*$$//'|sort|uniq -c|sort -nr > DataStats/u_who_cnt.log
	find $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o '<u [^>]*>'|sed 's/^.*who="//;s/" .*ana="/\t/;s/".*$$//'|sort|uniq -c|sort -nr > DataStats/u_who_ana_cnt.log
	find $(DATADIR)/tei-text/$*/ -type f |xargs cat|\
	   grep -o '<seg>[^<]*</seg>'|sort|uniq -c|grep -v "^ *1 <seg" |sort -nr > DataStats/seg_non_uniq.log
	find $(DATADIR)/tei-text/$*/ -type f |xargs cat|\
	   tr "\n" " "|sed "s/\(<[^<]*>[^>]*<desc[^>]*>[^<]*\)/\n\1\n\n\n/g"|\
	   grep '<desc'|sed 's/^<\([^ ]*\).*type="\([^"]*\)".*<desc[^>]*>/\1\t\2\t/'|\
	   sort|uniq -c|sort -nr > DataStats/incident_ana_cnt.log




######---------------
DEV-tei-text-stats-RUN-LAST = $(addprefix tei-text-stats-, $(TEI-TEXT_DATA_LAST))
DEV-tei-text-stats: $(DEV-tei-text-stats-RUN-LAST)
$(DEV-tei-text-stats-RUN-LAST): tei-text-stats-%:
	echo "statistics of $*"
	mkdir -p $(DATADIR)/tei-text-stats/$*/
	find $(DATADIR)/tei-text/$*/ -type f |xargs cat|\
	   grep -o '<note>[^<]*</note>'|sort|uniq -c|sort -n|nl > $(DATADIR)/tei-text-stats/$*/note_cnt.log
	find $(DATADIR)/tei-text/$*/ -type f |xargs cat|\
	   grep -o '<note type="time">[^<]*</note>'|sort|uniq -c|sort -n|nl > $(DATADIR)/tei-text-stats/$*/note_time_cnt.log
	find $(DATADIR)/tei-text/$*/ -type f |xargs cat|\
	   grep -o '<seg>[^<]*</seg>'|sort|uniq -c|grep -v "^ *1 <seg" |sort -n|nl > $(DATADIR)/tei-text-stats/$*/seg_non_uniq.log




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

