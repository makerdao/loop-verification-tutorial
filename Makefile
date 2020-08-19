DAPP_DIR = $(CURDIR)/dss
SRC_DIR = $(CURDIR)/src
SRCS = $(addprefix $(SRC_DIR)/, dss.md lemmas.k.md storage.k.md prelude.smt2.md)
DAPP_SRCS = $(wildcard $(DAPP_DIR)/src/*)
# if KLAB_OUT isn't defined, default is to use out/
ifdef KLAB_OUT
OUT_DIR = $(KLAB_OUT)
else
OUT_DIR = $(CURDIR)/out
endif
TMPDIR ?= $(CURDIR)/tmp
ifndef KLAB_EVMS_PATH
$(error $(red)Error$(reset): KLAB_EVMS_PATH must be defined and point to evm-semantics!)
endif
SPECS_DIR = $(OUT_DIR)/specs
ACTS_DIR = $(OUT_DIR)/acts
DOC_DIR = $(OUT_DIR)/doc

KLAB_FLAGS = KLAB_OUT=$(OUT_DIR)
KPROVE_SRCS = $(SPECS_DIR)/dss-verification.k

SMT_PRELUDE = $(OUT_DIR)/prelude.smt2
RULES = $(OUT_DIR)/rules.k

SPEC_MANIFEST = $(SPECS_DIR)/specs.manifest

PATH := $(CURDIR)/deps/klab/bin:$(PATH)
export PATH

.PHONY: all deps spec dapp kevm klab doc proofs proofs-fast \
        clean dapp-clean spec-clean doc-clean log-clean

all: deps spec

deps: dapp kevm klab

dapp:
	dapp --version
	git submodule update --init --recursive -- dss
	cd $(DAPP_DIR) && dapp --use solc:0.5.12 build && cd ../

kevm:
	git submodule update --init --recursive -- deps/evm-semantics
	cd deps/evm-semantics/                  \
	    && make deps RELEASE=true           \
	    && make build-java RELEASE=true -j4

klab:
	git submodule update --init --recursive -- deps/klab
	cd deps/klab/      \
	    && npm install

proof_names      = $(shell cat proofs)
proof_fast_names = $(shell cat proofs-fast)

PROVE = klab

proofs: $(proof_names:=.prove)
proofs-fast: $(proof_fast_names:=.prove)

%.prove:
	$(PROVE) prove $*

dapp-clean:
	cd $(DAPP_DIR) && dapp clean && cd ../

$(SPEC_MANIFEST): $(SRCS) $(DAPP_SRCS) $(KPROVE_SRCS)
	mkdir -p $(SPECS_DIR)
	$(KLAB_FLAGS) klab build

$(SPECS_DIR)/%.k: src/%.k
	mkdir -p $(SPECS_DIR)
	cp $< $@

spec: $(SPEC_MANIFEST)

spec-clean:
	rm -f $(SPECS_DIR)/* $(ACTS_DIR)/* $(SPEC_MANIFEST)

$(DOC_DIR)/dss.html: $(SRCS)
	$(info Generating html documentation: $@)
	mkdir -p $(DOC_DIR)
	$(KLAB_FLAGS) klab report > $@

doc: $(DOC_DIR)/dss.html

doc-clean:
	rm -rf $(DOC_DIR)/*

log-clean:
	rm -rf $(TMPDIR)/klab

clean: dapp-clean spec-clean doc-clean
