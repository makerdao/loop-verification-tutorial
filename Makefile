DAPP_DIR = $(CURDIR)/dss
SRC_DIR = $(CURDIR)/src
SRCS = $(addprefix $(SRC_DIR)/, dss.md lemmas.k.md storage.k.md prelude.smt2.md)
DAPP_SRCS = $(wildcard $(DAPP_DIR)/src/*)
# if KLAB_OUT isn't defined, default is to use out/
OUT_DIR_LOCAL  = out
KLAB_OUT_LOCAL = $(OUT_DIR_LOCAL)
OUT_DIR        = $(CURDIR)/$(OUT_DIR_LOCAL)
KLAB_OUT       = $(OUT_DIR)
KLAB_EVMS_PATH = $(CURDIR)/deps/evm-semantics
export KLAB_OUT
export KLAB_EVMS_PATH
TMPDIR ?= $(CURDIR)/tmp
SPECS_DIR = $(OUT_DIR)/specs
ACTS_DIR = $(OUT_DIR)/acts
DOC_DIR = $(OUT_DIR)/doc

KLAB       = klab
PROVE      = $(KLAB) prove
PROVE_DUMP = $(KLAB) prove --dump
PROVE_ARGS = --concrete-rules $(shell cat $(KLAB_EVMS_PATH)/tests/specs/mcd/concrete-rules.txt | tr '\n' ',')
BUILD      = $(KLAB) build-spec
GET_GAS    = $(KLAB) get-gas
SOLVE_GAS  = $(KLAB) solve-gas
HASH       = $(KLAB) hash
KLAB_MAKE  = $(KLAB) make

SMT_PRELUDE = $(OUT_DIR)/prelude.smt2
RULES = $(OUT_DIR)/rules.k

SPEC_MANIFEST = $(SPECS_DIR)/specs.manifest

PATH := $(CURDIR)/deps/klab/bin:$(KLAB_EVMS_PATH)/deps/k/k-distribution/target/release/k/bin:$(PATH)
export PATH

SPEC_SRCS = src/dss.md $(KLAB_OUT_LOCAL)/specs/verification.k

include.mak: Makefile deps/klab/makefile.timestamp $(SPEC_SRCS)
	$(KLAB_MAKE) > include.mak

include include.mak

.PHONY: all deps spec dapp kevm klab doc prove-work                      \
        clean dapp-clean spec-clean doc-clean log-clean gen-spec gen-gas

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

klab: deps/klab/makefile.timestamp

deps/klab/makefile.timestamp:
	git submodule update --init --recursive -- deps/klab
	cd deps/klab/                   \
	    && npm install              \
	    && make deps-haskell        \
	    && touch makefile.timestamp

$(KLAB_OUT_LOCAL)/specs/verification.k: src/verification.k
	@mkdir -p $(KLAB_OUT_LOCAL)/specs
	@mkdir -p $(KLAB_OUT_LOCAL)/specs
	@mkdir -p $(KLAB_OUT_LOCAL)/acts
	@mkdir -p $(KLAB_OUT_LOCAL)/gas
	@mkdir -p $(KLAB_OUT_LOCAL)/meta/name
	@mkdir -p $(KLAB_OUT_LOCAL)/meta/data
	@mkdir -p $(KLAB_OUT_LOCAL)/output
	@mkdir -p $(CURDIR)/specs
	cp $< $@

prove-work: KLAB=profile log-prove-work timeout 1200 klab
prove-work: $(shell cat proofs-work)

%.hash:
	$(HASH) $*

%.gen-spec: mkdirs
	$(BUILD) $* > $(OUT_DIR)/output/$@ 2>&1
	$(HASH) $*
	cp $(SPECS_DIR)/$$($(HASH) $*).k specs/$*.k

%.klab-view:
	$(KLAB) debug $$($(HASH) $*)

gen-spec: $(proof_names:=.gen-spec) $(proof_names_exhaustiveness:=.gen-spec)

%.gen-gas: $(KLAB_OUT_LOCAL)/gas/%
	cat $(KLAB_OUT_LOCAL)/gas/$$($(HASH) $*).raw.kast.json | jq '{ "format": "KAST", "version": 1.0, "term": . }' > $(KLAB_OUT_LOCAL)/gas/$*.json
	kast --directory deps/evm-semantics/.build/defn/java --input json --output pretty --sort Int $(KLAB_OUT_LOCAL)/gas/$*.json > specs/$*.gas

gen-gas: $(pass_rough_specs:=.gen-gas)

dapp-clean:
	cd $(DAPP_DIR) && dapp clean && cd ../

$(SPEC_MANIFEST): mkdirs $(SRCS) $(DAPP_SRCS) $(SPECS_SRCS)
	$(KLAB_FLAGS) klab build

$(SPECS_DIR)/%.k: src/%.k
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
