DAPP_DIR = $(CURDIR)/dss
SRC_DIR = $(CURDIR)/src
SRCS = $(addprefix $(SRC_DIR)/, dss.md lemmas.k.md storage.k.md prelude.smt2.md)
DAPP_SRCS = $(wildcard $(DAPP_DIR)/src/*)
# if KLAB_OUT isn't defined, default is to use out/
OUT_DIR        = $(CURDIR)/out
KLAB_OUT       = $(OUT_DIR)
KLAB_EVMS_PATH = $(CURDIR)/deps/evm-semantics
export KLAB_OUT
export KLAB_EVMS_PATH
TMPDIR ?= $(CURDIR)/tmp
SPECS_DIR = $(OUT_DIR)/specs
ACTS_DIR = $(OUT_DIR)/acts
DOC_DIR = $(OUT_DIR)/doc

KPROVE_SRCS = $(SPECS_DIR)/dss-verification.k

SMT_PRELUDE = $(OUT_DIR)/prelude.smt2
RULES = $(OUT_DIR)/rules.k

SPEC_MANIFEST = $(SPECS_DIR)/specs.manifest

PATH := $(CURDIR)/deps/klab/bin:$(PATH)
export PATH

.PHONY: all deps spec dapp kevm klab doc                                \
        build-stage1 build-stage2 build-gas-stage1                      \
        prove-stage1 prove-stage2                                       \
        clean dapp-clean spec-clean doc-clean log-clean gen-spec mkdirs

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

KLAB      = klab
PROVE     = $(KLAB) prove
BUILD     = $(KLAB) build-spec
GET_GAS   = $(KLAB) get-gas
SOLVE_GAS = $(KLAB) solve-gas
HASH      = $(KLAB) hash

proof_names_stage1 = $(shell cat proofs-stage1)
proof_names_stage2 = $(shell cat proofs-stage2)
proof_names_stage3 = $(shell cat proofs-stage3)

build-stage1: $(proof_names_stage1:=.build)
build-stage2: $(proof_names_stage2:=.build)
build-stage3: $(proof_names_stage3:=.build)

prove-stage1: $(proof_names_stage1:=.prove)
prove-stage2: $(proof_names_stage2:=.prove-gas)
prove-stage3: $(proof_names_stage3:=.prove-gas)

build-gas-stage1: $(proof_names_stage1:=.build-gas)

mkdirs:
	@mkdir -p $(OUT_DIR)/specs
	@mkdir -p $(OUT_DIR)/acts
	@mkdir -p $(OUT_DIR)/gas
	@mkdir -p $(OUT_DIR)/meta/name
	@mkdir -p $(OUT_DIR)/meta/data
	@mkdir -p $(OUT_DIR)/output
	@mkdir -p $(CURDIR)/specs

%.build: mkdirs
	$(BUILD) $* > $(OUT_DIR)/output/$@ 2>&1

%.prove: %.build $(KPROVE_SRCS)
	$(PROVE) $* > $(OUT_DIR)/output/$@ 2>&1

%.prove-dump: %.build $(KPROVE_SRCS)
	$(PROVE) --dump $* > $(OUT_DIR)/output/$@ 2>&1

%.build-gas: %.prove-dump
	$(GET_GAS)   $*
	$(SOLVE_GAS) $*

%.prove-gas: %_rough.build-gas
	$(PROVE) $* > $(OUT_DIR)/output/$@ 2>&1

%.hash:
	$(HASH) $*

%.gen-spec: mkdirs
	$(BUILD) $* > $(OUT_DIR)/output/$@ 2>&1
	$(HASH) $*
	cp $(SPECS_DIR)/$$($(HASH) $*).k specs/$*.k

%.klab-view:
	$(KLAB) debug $$($(HASH) $*)

gen-spec: $(proof_names:=.gen-spec) $(proof_names_exhaustiveness:=.gen-spec)

dapp-clean:
	cd $(DAPP_DIR) && dapp clean && cd ../

$(SPEC_MANIFEST): mkdirs $(SRCS) $(DAPP_SRCS) $(KPROVE_SRCS)
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
