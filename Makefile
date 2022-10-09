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
$(download-NN): download-%: %
	./Scripts/download.sh -t $< -d $(DATE) -O $(DATADIR) -c Scripts/config.sh || echo "$@: NO NEW DATA"











######---------------
.PHONY: $(TERMS)
$(TERMS):

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

