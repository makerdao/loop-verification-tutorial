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
KLAB_EVMS_PATH=$(CURDIR)/deps/evm-semantics
endif
export KLAB_EVMS_PATH
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

.PHONY: all deps spec dapp kevm klab doc proofs-stage1 proofs-stage2 proofs-fast proofs-work \
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
	cd deps/klab/            \
	    && npm install       \
	    && make deps-haskell

proof_names_stage1 = $(shell cat proofs-stage1)
proof_names_stage2 = $(shell cat proofs-stage2)
proof_fast_names   = $(shell cat proofs-fast)
proof_work_names   = $(shell cat proofs-work)

PROVE = klab

proofs-stage1: $(proof_names_stage1:=.prove-stage1)
proofs-stage2: $(proof_names_stage2:=.prove-stage2)
proofs-fast: $(proof_fast_names:=.prove)
proofs-work: $(proof_work_names:=.prove)

%.prove:
	@mkdir -p $(OUT_DIR)/output
	$(PROVE) prove $* > $(OUT_DIR)/output/$@.out 2>&1

%.prove-stage1:
	@mkdir -p $(OUT_DIR)/output
	$(PROVE) prove --dump $* > $(OUT_DIR)/output/$@.out 2>&1

%_rough.klab-gas: %_rough.prove-stage1
	$(KLAB_FLAGS) klab get-gas   $*_rough
	$(KLAB_FLAGS) klab solve-gas $*_rough

%.prove-stage2: %_rough.klab-gas
	$(MAKE) spec
	$(PROVE) prove --dump $* > $(OUT_DIR)/output/$@.out 2>&1

%.hash:
	klab hash $*

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
