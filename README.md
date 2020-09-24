# About

This is a tutorial of how to formally verify function containing a loop using `klab`.

# Building and Running Proofs

Prerequisites: `Z3` version `4.8.7` available on `PATH`.

```
git submodule update --init --recursive
unset KLAB_OUT
unset KLAB_EVMS_VERSION
make dapp
make deps RELEASE=true -B
make prove
```

#Explanation

TODO
