.DEFAULT_GOAL := help

s = java -jar /usr/share/java/saxon.jar
xpath = xargs -I % java -cp /usr/share/java/saxon.jar net.sf.saxon.Query -xi:off \!method=adaptive -s:% -qs:


##$TERMS## Terms that are processed.
TERMS = 7 8 9
##$DATADIR## Folder with country corpus folders. Default value is 'Data'.
DATA := $(shell sh -c 'test `hostname` = "parczech" && echo -n "/opt/ParlaMint-UA" || pwd')
DATADIR = ${DATA}/Data
TAXONOMIES := $(shell sh -c 'test `hostname` = "parczech" && echo -n "/opt/ParlaMint-UA/current/Taxonomies" || echo -n `pwd`"/Taxonomies"')

DATE := $(shell sh -c 'date +"%Y%m%dT%H%M%S"')

GSID := 2PACX-1vRTvI3QU1_q3V8cyVHeDv_Uo_OSDwuwYlmQgNq6OMClZ3QN5-5xKQ1uv34GvWV9Mvorv8ul4qJQoyEU
GSIDperson := 983620751
GSIDaffiliation := 1800909923
GSIDorg := 1140033767
GSIDevent := 19173850
GSIDrelation := 1419083904


-include Makefile.env

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
	                           --subdir-by-year \
	                           --data-dir "$(DATADIR)" \
	                           --config Scripts/config.sh \
	                           --file-id "ParlaMint-UA" \
	                           $(PROCESS_SUBSET)


tei-text-lang-RUN-ALL = $(addprefix tei-text-lang-, $(TEI-TEXT_DATA_ALL))
tei-text-lang-RUN-LAST = $(addprefix tei-text-lang-, $(TEI-TEXT_DATA_LAST))
## tei-text-lang ## tei-text-langs
tei-text-lang: tei-text-lang-last
tei-text-lang-last: $(tei-text-lang-RUN-LAST)
tei-text-lang-all: $(tei-text-lang-RUN-ALL)

## tei-text-lang-RUN ##
$(tei-text-lang-RUN-ALL): tei-text-lang-%:
	mkdir -p $(DATADIR)/tei-text-lang/$*/
	rm -rf $(DATADIR)/tei-text-lang/$*/*
	./Scripts/lang-detect.pl   --id $* \
	                           --data-dir "$(DATADIR)" \
	                           --config Scripts/config.sh \
	                           --lang "uk:en=ukrainian,uk=????????????????????" \
	                           --lang "ru:en=russian,uk=??????????????????" \
	                           --speaker-lang-stats




TEI-TEXT-LANG_DATA_LAST := $(shell ls $(DATADIR)/tei-text-lang | grep -v '_' | sort -r | head -n1)
TEI-TEXT-LANG_DATA_ALL := $(shell ls $(DATADIR)/tei-text-lang )

link-speakers2tei-text-RUN-ALL = $(addprefix link-speakers2tei-text-, $(TEI-TEXT-LANG_DATA_ALL))
link-speakers2tei-text-RUN-LAST = $(addprefix link-speakers2tei-text-, $(TEI-TEXT-LANG_DATA_LAST))
## link-speakers2tei-text ## link-speakers2tei-texts
link-speakers2tei-text: link-speakers2tei-text-last
link-speakers2tei-text-last: $(link-speakers2tei-text-RUN-LAST)
link-speakers2tei-text-all: $(link-speakers2tei-text-RUN-ALL)

## link-speakers2tei-text-RUN ##
$(link-speakers2tei-text-RUN-ALL): link-speakers2tei-text-%:
	mkdir -p $(DATADIR)/tei-text-speakers/$*/
	rm -rf $(DATADIR)/tei-text-speakers/$*/*
	$s -xsl:Scripts/link-speakers2tei-text.xsl \
	   -o:$(DATADIR)/tei-text-speakers/$*/ParlaMint-UA.xml \
	      speaker-links="$(DATADIR)/tei-particDesc-preprocess/$(DOWNLOAD_META_DATA_LAST)/mp-data-aliases.tsv" \
	      in-dir="$(DATADIR)/tei-text-lang/$*/" \
	      out-dir="$(DATADIR)/tei-text-speakers/$*/" \
	      $(DATADIR)/tei-text/$*/ParlaMint-UA.xml


link-speakers-RUN-ALL = $(addprefix link-speakers-, $(TEI-TEXT_DATA_ALL))
link-speakers-RUN-LAST = $(addprefix link-speakers-, $(TEI-TEXT_DATA_LAST))
## link-speakers ## link-speakerss
link-speakers: link-speakers-last
link-speakers-last: $(link-speakers-RUN-LAST)
link-speakers-all: $(link-speakers-RUN-ALL)

## link-speakers-RUN ##
$(link-speakers-RUN-ALL): link-speakers-%:
	mkdir -p $(DATADIR)/link-speakers/$*/
	rm -f $(DATADIR)/link-speakers/$*/*
	./Scripts/link-speakers.pl --id $* \
	                           --data-dir "$(DATADIR)" \
	                           --config Scripts/config.sh \
	                           --speaker-aliases "$(DATADIR)/tei-particDesc-preprocess/$(DOWNLOAD_META_DATA_LAST)/mp-data-aliases.tsv" \
	                           --plenary-speech "$(DATADIR)/tei-particDesc-preprocess/$(DOWNLOAD_META_DATA_LAST)/plenary-speech.xml" \
	                           --speaker-calls "$(DATADIR)/speaker-calls/$*/calls-speakers.tsv"





TEI-TEXT-SPEAKERS_DATA_LAST := $(shell ls $(DATADIR)/tei-text-speakers | grep -v '_' | sort -r | head -n1)
TEI-TEXT-SPEAKERS_DATA_ALL := $(shell ls $(DATADIR)/tei-text-speakers )
tei-UD-RUN-LAST = $(addprefix tei-UD-, $(TEI-TEXT-LANG_DATA_LAST))
tei-UD-RUN-ALL = $(addprefix tei-UD-, $(TEI-TEXT-LANG_DATA_ALL))
tei-UD: tei-UD-last
tei-UD-last: $(tei-UD-RUN-LAST)
tei-UD-all: $(tei-UD-RUN-ALL)

$(tei-UD-RUN-ALL): tei-UD-%: lib udpipe2
	echo "TODO: preprocess with language detection"
	mkdir -p $(DATADIR)/tei-UD/$*/
	find $(DATADIR)/tei-text-lang/$*/ -type f -printf "%P\n" |sort| grep 'ParlaMint-UA_' > $(DATADIR)/tei-UD/$*.fl
	cp $(DATADIR)/tei-text-lang/$*/ParlaMint-UA.xml $(DATADIR)/tei-UD/$*/
	perl -I lib udpipe2/udpipe2.pl --colon2underscore \
	                             $(TOKEN) \
	                             --model "uk:ukrainian-iu-ud-2.10-220711" \
	                             --model "ru:russian-syntagrus-ud-2.10-220711" \
	                             --elements "seg" \
	                             --debug \
	                             --try2continue-on-error \
	                             --filelist $(DATADIR)/tei-UD/$*.fl \
	                             --input-dir $(DATADIR)/tei-text-lang/$*/ \
	                             --output-dir $(DATADIR)/tei-UD/$*/





TEI-UD_DATA_LAST := $(shell ls $(DATADIR)/tei-UD | grep -v '_'|grep -v '\.fl$$' | sort -r | head -n1)
TEI-UD_DATA_ALL := $(shell ls $(DATADIR)/tei-UD | grep -v '\.fl$$')
speaker-calls-RUN-ALL = $(addprefix speaker-calls-, $(TEI-UD_DATA_ALL))
speaker-calls-RUN-LAST = $(addprefix speaker-calls-, $(TEI-UD_DATA_LAST))
## speaker-calls ## speaker-callss
speaker-calls: speaker-calls-last
speaker-calls-last: $(speaker-calls-RUN-LAST)
speaker-calls-all: $(speaker-calls-RUN-ALL)

## speaker-calls-RUN ##
$(speaker-calls-RUN-ALL): speaker-calls-%:
	mkdir -p $(DATADIR)/speaker-calls/$*/
	rm -f $(DATADIR)/speaker-calls/$*/*
	./Scripts/speaker-calls.pl --id $* \
	                           --data-dir "$(DATADIR)" \
	                           --config Scripts/config.sh



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
	wget https://data.rada.gov.ua/ogd/zal/ppz/skl$*/plenary_speech-skl$*.csv -O $(DATADIR)/download-meta/$(DATE)/ogd_zal_ppz_skl$*_plenary_speech-skl$*.csv

DOWNLOAD_META_DATA_LAST := $(shell ls $(DATADIR)/download-meta | grep -v '_' | sort -r | head -n1)
tei-particDesc-RUN-LAST = $(addprefix tei-particDesc-, $(DOWNLOAD_META_DATA_LAST))
DOWNLOAD_META_DATA_LAST_TERMS = $(shell ls $(DATADIR)/download-meta/$(DOWNLOAD_META_DATA_LAST)/ogd_mps_skl*_mps-data.xml|sed "s/^.*skl\([0-9]*\)_.*$$/\1/"|tr "\n" " "|sed "s/ *$$//")

tei-particDesc: $(tei-particDesc-RUN-LAST)
$(tei-particDesc-RUN-LAST): tei-particDesc-%: tei-particDesc-preprocess-% tei-particDesc-gov-%
	mkdir -p $(DATADIR)/tei-particDesc-working/$*
	mkdir -p $(DATADIR)/tei-particDesc/$*
	@echo "TODO: PROCESS META $*"
	@echo "input files:"
	@find $(DATADIR)/tei-particDesc-preprocess/$* -type f|sed 's/^/\t/'
	echo "<?xml version=\"1.0\" ?>\n<root/>" | \
	  $s -s:- -xsl:Scripts/metadata.xsl \
	      in-dir=$(DATADIR)/tei-particDesc-preprocess/$(DOWNLOAD_META_DATA_LAST)/ \
	      out-dir=$(DATADIR)/tei-particDesc/$(DOWNLOAD_META_DATA_LAST)/




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
	echo "<?xml version=\"1.0\" ?>\n<root/>" | \
	  $s -s:- -xsl:Scripts/metadata-preprocess.xsl \
	      terms="$(DOWNLOAD_META_DATA_LAST_TERMS)" \
	      in-dir=$(DATADIR)/tei-particDesc-preprocess/$*/ \
	      out-dir=$(DATADIR)/tei-particDesc-preprocess/$*/

tei-particDesc-gov-RUN-LAST = $(addprefix tei-particDesc-gov-, $(DOWNLOAD_META_DATA_LAST))
tei-particDesc-gov: $(tei-particDesc-gov-RUN-LAST)
$(tei-particDesc-gov-RUN-LAST): tei-particDesc-gov-%:
	mkdir -p $(DATADIR)/tei-particDesc-preprocess/$*
	@echo "downloading gov persons and manually added organizations"
	curl -L "https://docs.google.com/spreadsheets/d/e/$(GSID)/pub?gid=$(GSIDperson)&single=true&output=tsv" > $(DATADIR)/tei-particDesc-preprocess/$*/gov-person.tsv
	curl -L "https://docs.google.com/spreadsheets/d/e/$(GSID)/pub?gid=$(GSIDaffiliation)&single=true&output=tsv" > $(DATADIR)/tei-particDesc-preprocess/$*/gov-affiliation.tsv
	curl -L "https://docs.google.com/spreadsheets/d/e/$(GSID)/pub?gid=$(GSIDorg)&single=true&output=tsv" > $(DATADIR)/tei-particDesc-preprocess/$*/gov-org.tsv
	curl -L "https://docs.google.com/spreadsheets/d/e/$(GSID)/pub?gid=$(GSIDevent)&single=true&output=tsv" > $(DATADIR)/tei-particDesc-preprocess/$*/gov-event.tsv
	curl -L "https://docs.google.com/spreadsheets/d/e/$(GSID)/pub?gid=$(GSIDrelation)&single=true&output=tsv" > $(DATADIR)/tei-particDesc-preprocess/$*/gov-relation.tsv


######

PARTICDESC_DATA_LAST := $(shell ls $(DATADIR)/tei-particDesc | grep -v '_' | sort -r | head -n1)


TEI.ana-RUN-ALL = $(addprefix TEI.ana-, $(TEI-UD_DATA_ALL))
TEI.ana-RUN-LAST = $(addprefix TEI.ana-, $(TEI-UD_DATA_LAST))
## TEI.ana ## TEI.anas
TEI.ana: TEI.ana-last
TEI.ana-last: $(TEI.ana-RUN-LAST)
TEI.ana-all: $(TEI.ana-RUN-ALL)

## TEI.ana-RUN ##
$(TEI.ana-RUN-ALL): TEI.ana-%:
	mkdir -p $(DATADIR)/release/$*
	$s -xsl:Scripts/ParlaMint-UA-finalize.xsl \
	    outDir=$(DATADIR)/release/$* \
	    inListPerson=$(DATADIR)/tei-particDesc/$(PARTICDESC_DATA_LAST)/ParlaMint-UA-listPerson.xml  \
	    inListOrg=$(DATADIR)/tei-particDesc/$(PARTICDESC_DATA_LAST)/ParlaMint-UA-listOrg.xml \
	    inTaxonomiesDir=$(TAXONOMIES) \
	    type=TEI.ana \
	    $(DATADIR)/tei-UD/$*/ParlaMint-UA.xml

TEI-RUN-ALL = $(addprefix TEI-, $(TEI-UD_DATA_ALL))
TEI-RUN-LAST = $(addprefix TEI-, $(TEI-UD_DATA_LAST))
## TEI.ana ## TEI.anas
TEI: TEI-last
TEI-last: $(TEI-RUN-LAST)
TEI-all: $(TEI-RUN-ALL)

## TEI-RUN ##
$(TEI-RUN-ALL): TEI-%:
	mkdir -p $(DATADIR)/release/$*
	$s -xsl:Scripts/ParlaMint-UA-finalize.xsl \
	    outDir=$(DATADIR)/release/$* \
	    inListPerson=$(DATADIR)/tei-particDesc/$(PARTICDESC_DATA_LAST)/ParlaMint-UA-listPerson.xml  \
	    inListOrg=$(DATADIR)/tei-particDesc/$(PARTICDESC_DATA_LAST)/ParlaMint-UA-listOrg.xml \
	    inTaxonomiesDir=$(TAXONOMIES) \
	    anaDir=$(DATADIR)/release/$*/ParlaMint-UA.TEI.ana \
	    type=TEI \
	    $(DATADIR)/tei-text-lang/$*/ParlaMint-UA.xml


###### other:
create-metadata-sample:
	rm -rf SampleMetaData/*
	mkdir -p SampleMetaData/01-source
	mkdir -p SampleMetaData/02-preprocess
	mkdir -p SampleMetaData/03-ParlaMint-UA
	find $(DATADIR)/tei-particDesc-preprocess/$(DOWNLOAD_META_DATA_LAST)/ -name "ogd_mps_skl*_mps*-data.xml" | xargs -I {} cp {} SampleMetaData/01-source/
	find $(DATADIR)/tei-particDesc-preprocess/$(DOWNLOAD_META_DATA_LAST)/ -name "mp-data*.*"|grep -v "mp-data-stats" | xargs -I {} cp {} SampleMetaData/02-preprocess/
	find $(DATADIR)/tei-particDesc-preprocess/$(DOWNLOAD_META_DATA_LAST)/ -name "plenary-speech.xml"| xargs -I {} cp {} SampleMetaData/02-preprocess/
	find $(DATADIR)/tei-particDesc-preprocess/$(DOWNLOAD_META_DATA_LAST)/ -name "mp-data-stats*.*" | xargs -I {} cp {} DataStats/
	find $(DATADIR)/tei-particDesc-preprocess/$(DOWNLOAD_META_DATA_LAST)/ -name "gov-*.tsv" | xargs -I {} cp {} SampleMetaData/02-preprocess/
	find $(DATADIR)/tei-particDesc/$(DOWNLOAD_META_DATA_LAST)/ -name "ParlaMint-UA-list*.xml"| xargs -I {} cp {} SampleMetaData/03-ParlaMint-UA/


create-february-sample:
	rm -rf SampleData/*
	mkdir -p SampleData/01-htm
	mkdir -p SampleData/02-tei-text
	mkdir -p SampleData/03-tei-text-lang
	mkdir -p SampleData/04-tei-text-speakers
	mkdir -p SampleData/05-tei-UD
	mkdir -p SampleData/06-speaker-calls
	ls $(DATADIR)/download/$(TEI-TEXT_DATA_LAST)/20??02??*.htm | xargs -I {} cp {} SampleData/01-htm/
	ls $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ParlaMint-UA_20??-02-??*.xml | xargs -I {} cp {} SampleData/02-tei-text/
	ls $(DATADIR)/tei-text-lang/$(TEI-TEXT_DATA_LAST)/ParlaMint-UA_20??-02-??*.xml | xargs -I {} cp {} SampleData/03-tei-text-lang/
	ls $(DATADIR)/tei-text-speakers/$(TEI-TEXT_DATA_LAST)/ParlaMint-UA_20??-02-??*.xml | xargs -I {} cp {} SampleData/04-tei-text-speakers/
	ls $(DATADIR)/speaker-calls/_FEBRUARY/* | xargs -I {} cp {} SampleData/06-speaker-calls/


create-all-stats:
	#rm -rf DataStats/*
	mkdir -p DataStats
	cp $(DATADIR)/tei-text-lang/$(TEI-TEXT_DATA_LAST)/speaker_lang_stat.tsv DataStats/
	find $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o '<note>[^<]*</note>'|sort|uniq -c|sort -nr > DataStats/note_cnt.log
	find $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o '<note type="speaker">[^<]*</note>'|sed "s/^[^>]*>//;s/<.*$$//"|sort|uniq -c|sort -nr > DataStats/note_speaker_cnt.log
	find $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o '<u [^>]*>'|sed 's/^.*who="//;s/".*$$//'|sort|uniq -c|sort -nr > DataStats/u_who_cnt.log
	find $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o '<u [^>]*>'|sed 's/^.*who="//;s/" .*ana="/\t/;s/".*$$//'|sort|uniq -c|sort -nr > DataStats/u_who_ana_cnt.log
	find $(DATADIR)/tei-text-speakers/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   tr "\n" " "|sed 's/>/>\n/g'|grep -o '<u [^>]*>'|sed 's/^.*who="//;s/" .*ana="/\t/;s/".*$$//'|sort|uniq -c|sort -nr > DataStats/u_whoref_ana_cnt.log
	find $(DATADIR)/tei-text-speakers/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o 'who="[^#"]*"'|sed 's/^who="\(.*\)"/\1/'|sort|uniq -c|sort -nr > DataStats/u_who-no-attrib_cnt.log
	find $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   grep -o '<seg[^<]*>[^<]*</seg>'|sed 's/<seg[^<]*>/<seg>/'|sort|uniq -c|grep -v "^ *1 <seg" |sort -nr > DataStats/seg_non_uniq.log
	find $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/ -type f |xargs cat|\
	   tr "\n" " "|sed "s/\(<[^<]*>[^>]*<desc[^>]*>[^<]*\)/\n\1\n\n\n/g"|\
	   grep '<desc'|sed -E 's/^<([^ ]*).*(type|reason)="([^"]*)".*<desc[^>]*>/\1\t\3\t/'|\
	   sort|uniq -c|sort -nr > DataStats/incident_ana_cnt.log

search-text:
	mkdir -p DataSearchResults
	grep -rnioP '????????????[\p{Lu}\p{Lt}\p{Ll}]*[^\.]{0,20}?(?:\s+\p{Lu}[\p{Lu}\p{Lt}\p{Ll}]*){3}' $(DATADIR)/tei-text/$(TEI-TEXT_DATA_LAST)/\
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
prereq: udpipe2 lib

udpipe2:
	svn checkout https://github.com/ufal/ParCzech/trunk/src/udpipe2
lib:
	svn checkout https://github.com/ufal/ParCzech/trunk/src/lib
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

