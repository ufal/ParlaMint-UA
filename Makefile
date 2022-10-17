.DEFAULT_GOAL := help

s = java -jar /usr/share/java/saxon.jar
xpath = xargs -I % java -cp /usr/share/java/saxon.jar net.sf.saxon.Query -xi:off \!method=adaptive -s:% -qs:


##$TERMS## Terms that are processed.
TERMS = 7 8 9
##$DATADIR## Folder with country corpus folders. Default value is 'Data'.
DATADIR = Data

DATE := $(shell sh -c 'date +"%Y%m%dT%H%M%S"')


.PHONY: $(download-NN) download
download-NN = $(addprefix download-, $(TERMS))
## download ## downloads new data from all terms defined in variable TERM
download: $(download-NN)
## download-NN ## Downloads new data from term NN
$(download-NN): download-%:
	./Scripts/download.sh -t $* -d $(DATE) -O $(DATADIR) -c Scripts/config.sh || echo "$@: NO NEW DATA"



DOWNLOAD_DATA_ALL := $(shell ls $(DATADIR)/download)
DOWNLOAD_DATA_LAST := $(shell ls $(DATADIR)/download | sort -r | head -n1)
TEI-TEXT_DATA_ALL := $(shell ls $(DATADIR)/tei-text)
TEI-TEXT_DATA_LAST := $(shell ls $(DATADIR)/tei-text | sort -r | head -n1)

#PROCESS_SUBSET := --process-subset "20[012].022[34]"
# PROCESS_SUBSET := --process-subset "20[12].....-?.?"

.PHONY: $(html2tei-text-RUN) html2tei-text
html2tei-text-RUN-ALL = $(addprefix html2tei-text-, $(DOWNLOAD_DATA_ALL))
html2tei-text-RUN-LAST = $(addprefix html2tei-text-, $(DOWNLOAD_DATA_LAST))
## html2tei-text ## html2tei-texts
html2tei-text: html2tei-text-last
html2tei-text-last: $(html2tei-text-RUN-LAST)
html2tei-text-all: $(html2tei-text-RUN-ALL)

## html2tei-text-RUN ##
$(html2tei-text-RUN-ALL): html2tei-text-%:
	echo "TODO $*"
	./Scripts/html2tei-text.pl --id $* \
	                           --data-dir "$(DATADIR)" \
	                           --config Scripts/config.sh \
	                           --file-id "ParlaMint-UA" \
	                           $(PROCESS_SUBSET)





create-february-sample:
	rm -rf SampleData/*
	mkdir -p SampleData/01-htm
	mkdir -p SampleData/02-tei-text
	ls $(DATADIR)/download/$(TEI-TEXT_DATA_LAST)/20??02??*.htm | xargs -I {} cp {} SampleData/01-htm/
	ls $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ParlaMint-UA_20??-02-??*.xml | xargs -I {} cp {} SampleData/02-tei-text/





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

