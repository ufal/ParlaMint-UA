s = java -jar /usr/share/java/saxon.jar
SOURCEDATA = Release/ParlaMint-UA.TEI.ana
WORKING = Working/
NERtaskSeed = 4
NERtaskMinW = 600
NERtaskMaxW = 8000
NERtaskTestLen = 6
NERtaskTrainLen = 6
NERtaskData =
YEARS = 12-13 14-15 16-17 18-19 20-21 22-23

$(WORKING)RANDOM:
	openssl enc -aes-256-ctr -pass pass:"$(NERtaskSeed)" -nosalt </dev/zero 2>/dev/null \
	| head -c 1M > $@

$(WORKING):
	mkdir -p  $@

file-wordcnt.tsv:
	find  $(SOURCEDATA) -type f -name "*_*.ana.xml" \
	| sort \
	| xargs -I {} sh -c "grep -HF  'unit=\"words\"' {}|head -n 1 " \
	| sed "s/.*ParlaMint-UA.TEI.ana\///;s/:.*quantity=\"/\t/;s/\".*$$//" \
	> $@

$(WORKING)file-wordcnt.sub.tsv: file-wordcnt.tsv $(WORKING)
	cat $< \
	| awk '( $$2 <= $(NERtaskMaxW) && $$2 >= $(NERtaskMinW)){print}' \
	> $@


file-wordcnt.years.sub = $(addsuffix .sub.tsv, $(addprefix $(WORKING)file-wordcnt., $(YEARS)) )

$(file-wordcnt.years.sub): $(WORKING)file-wordcnt.%.sub.tsv: $(WORKING)file-wordcnt.sub.tsv $(WORKING)RANDOM
	@echo "$@: $*"
	cat $(WORKING)file-wordcnt.sub.tsv | grep -P `echo "$*"|tr "-" "|" | sed "s/^/^20(/;s/$$/)/"` \
	|shuf --random-source=$(WORKING)RANDOM \
	> $@

$(WORKING)file-wordcnt.shuf.sub.tsv: $(file-wordcnt.years.sub)
	paste -d"\n" $^ | sed  '/^$$/d' > $@


$(WORKING)test.fl: $(WORKING)file-wordcnt.shuf.sub.tsv
	head -n $(NERtaskTestLen) $< | cut -f 1 > $@

train-set: $(WORKING)file-wordcnt.shuf.sub.tsv
	tail -n +$$(( $(NERtaskTestLen) + 1 )) $< \
	| cut -f 1 \
	| split -d --suffix-length=2 --additional-suffix=".fl" --lines $(NERtaskTrainLen) - "$(WORKING)train."

Scripts/ParlaMintNER2brat.xsl:
	mkdir Scripts || :
	wget -O Scripts/ParlaMintNER2brat.xsl https://raw.githubusercontent.com/ufal/ParlaMint-UA/main/Scripts/ParlaMintNER2brat.xsl


prepare-annotation-task-TEI: $(WORKING)test.fl train-set
	mkdir Data || :
	mkdir -p Data/Source/TEI.ana && \
	for set in `ls $(WORKING)*.fl | sed 's@.*/@@;s@.fl$$@@' `; do \
	  echo "$$set"; \
	  mkdir Data/Source/TEI.ana/$$set ; \
	  cat $(WORKING)$$set.fl|xargs -I {} cp $(SOURCEDATA)/{} Data/Source/TEI.ana/$$set/ ; \
	done || :

prepare-annotation-task-brat: prepare-annotation-task-TEI Scripts/ParlaMintNER2brat.xsl
	mkdir -p Data/Source/brat && \
	for xml in `cd Data/Source/TEI.ana ; ls */*.xml`; \
	do \
	  $s -xsl:Scripts/ParlaMintNER2brat.xsl \
	    outFilePrefix="Data/Source/brat/$$xml" \
	    tokenize=1 \
	    lang=uk \
	    Data/Source/TEI.ana/$$xml ;\
	done || :

prepare-annotation-task: prepare-annotation-task-brat
	mkdir -p Data/Annotation && \
	rsync -a Data/Source/brat/* Data/Annotation




annotation-task-stat:
	@for d in `find Data/brat -mindepth 1 -type d|sort`; do \
	  echo -n "$$d\nwords:\t" ; \
	  cat $$d/*.txt|wc -w ;\
	  echo -n "NEs:\t" ;\
	  cat $$d/*.ann|grep -c "^T" ;\
	  echo -n "PER:\t" ;\
	  cat $$d/*.ann|grep -c "PER " ;\
	  echo -n "ORG:\t" ;\
	  cat $$d/*.ann|grep -c "ORG " ;\
	  echo -n "LOC:\t" ;\
	  cat $$d/*.ann|grep -c "LOC " ;\
	  echo -n "MISC:\t" ;\
	  cat $$d/*.ann|grep -c "MISC " ;\
	done
	@echo '------- $(NERtaskSeed) $(NERtaskMinW) $(NERtaskMaxW)'
	@echo -n "train words:\t"
	@cat Data/brat/train*/*.txt|wc -w
	@echo -n "test words:\t"
	@cat Data/brat/test*/*.txt|wc -w



