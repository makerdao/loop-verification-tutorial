#!/usr/bin/env bash

spec_out="$1"
mkdir -p $spec_out
while read spec; do
    cp out/specs/$(klab hash $spec).k "$spec_out"/$spec.k
done < proofs
