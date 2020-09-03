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

KLAB_FLAGS = KLAB_OUT=$(OUT_DIR)
KPROVE_SRCS = $(SPECS_DIR)/dss-verification.k

SMT_PRELUDE = $(OUT_DIR)/prelude.smt2
RULES = $(OUT_DIR)/rules.k

SPEC_MANIFEST = $(SPECS_DIR)/specs.manifest

PATH := $(CURDIR)/deps/klab/bin:$(PATH)
export PATH

.PHONY: all deps spec dapp kevm klab doc \
	    build build-exhaustiveness build-gas build-fast build-work \
	    prove prove-exhaustiveness prove-gas prove-fast prove-work \
        clean dapp-clean spec-clean doc-clean log-clean gen-spec

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

proof_names_exhaustiveness = $(shell cat proofs-exhaustiveness)
proof_names                = $(shell cat proofs)
proof_names_gas            = $(shell cat proofs-gas)
proof_fast_names           = $(shell cat proofs-fast)
proof_work_names           = $(shell cat proofs-work)

PROVE     = klab prove
BUILD     = klab build-spec
GET_GAS   = klab get-gas
SOLVE_GAS = klab solve-gas
HASH      = klab hash

prove-exhaustiveness: $(proof_names_exhaustiveness:=.prove)
prove:                $(proof_names:=.prove)
prove-gas:            $(proof_names_gas:=.prove-gas)
prove-fast:           $(proof_fast_names:=.prove)
prove-work:           $(proof_work_names:=.prove)

build-exhaustiveness: $(proof_names_exhaustiveness:=.build)
build:                $(proof_names:=.build)
build-gas:            $(proof_names_gas:=.build)
build-fast:           $(proof_fast_names:=.build)
build-work:           $(proof_work_names:=.build)

mkdirs:
	@mkdir -p $(OUT_DIR)/specs
	@mkdir -p $(OUT_DIR)/acts
	@mkdir -p $(OUT_DIR)/gas
	@mkdir -p $(OUT_DIR)/meta/name
	@mkdir -p $(OUT_DIR)/meta/data
	@mkdir -p $(OUT_DIR)/output
	@mkdir -p specs

%.build: mkdirs
	$(KLAB_FLAGS) $(BUILD) $* > $(OUT_DIR)/output/$@ 2>&1

%.prove: %.build $(KPROVE_SRCS)
	$(KLAB_FLAGS) $(PROVE) $* > $(OUT_DIR)/output/$@ 2>&1

%.prove-dump: %.build $(KPROVE_SRCS)
	$(KLAB_FLAGS) $(PROVE) --dump $* > $(OUT_DIR)/output/$@ 2>&1

%.build-with-gas: %_rough.prove-dump
	$(KLAB_FLAGS) $(GET_GAS)   $*_rough
	$(KLAB_FLAGS) $(SOLVE_GAS) $*_rough

%.prove-gas: %.build-with-gas
	$(MAKE) $*.prove

%.hash:
	$(KLAB_FLAGS) $(HASH) $*

%.gen-spec: mkdirs
	$(KLAB_FLAGS) $(BUILD) $* > $(OUT_DIR)/output/$@ 2>&1
	$(KLAB_FLAGS) cp $(SPECS_DIR)/$(shell klab hash $*).k specs/$*.k

gen-spec: $(proof_names:=.gen-spec) $(proof_names_exhaustiveness:=.gen-spec)

dapp-clean:
	cd $(DAPP_DIR) && dapp clean && cd ../

$(SPEC_MANIFEST): $(SRCS) $(DAPP_SRCS) $(KPROVE_SRCS)
	mkdir -p $(SPECS_DIR)
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
