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
        build-stage1-rough build-stage1-non-rough build-stage2-rough    \
        prove-stage1-rough prove-stage1-non-rough prove-stage2-rough    \
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

KLAB       = klab
PROVE      = $(KLAB) prove
PROVE_DUMP = $(KLAB) prove --dump
BUILD      = $(KLAB) build-spec
GET_GAS    = $(KLAB) get-gas
SOLVE_GAS  = $(KLAB) solve-gas
HASH       = $(KLAB) hash

proofs_stage1_rough     = $(shell cat proofs-stage1-rough)
proofs_stage1_non_rough = $(shell cat proofs-stage1-non-rough)
proofs_stage2_rough     = $(shell cat proofs-stage2-rough)

build-exhaustiveness:   $(proofs_exhaustiveness:=.build)
build-stage1-rough:     $(proofs_stage1_rough:=.build)
build-stage1-non-rough: $(proofs_stage1_non_rough:=.build)
build-stage2-rough:     $(proofs_stage2_rough:=.build)

prove-exhaustiveness:   $(proofs_exhaustiveness:=.prove)
prove-stage1-rough:     $(proofs_stage1_rough:=.prove-rough)
prove-stage1-non-rough: $(proofs_stage1_non_rough:=.prove-non-rough)
prove-stage2-rough:     $(proofs_stage2_rough:=.prove-rough)

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
	$(PROVE_DUMP) $* > $(OUT_DIR)/output/$@ 2>&1

%.build-gas: %_rough.prove-dump
	$(BUILD) $* > $(OUT_DIR)/output/$@ 2>&1

%.prove-gas: %.build $(KPROVE_SRCS)
	$(PROVE_DUMP) $* > $(OUT_DIR)/output/$@ 2>&1

%.prove-rough: $(KPROVE_SRCS)
	$(PROVE_DUMP) $* > $(OUT_DIR)/output/$@ 2>&1
	$(GET_GAS)   $*
	$(SOLVE_GAS) $*

%.prove-non-rough:
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
