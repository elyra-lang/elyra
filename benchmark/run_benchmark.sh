#!/usr/bin/env bash

python3 ./gen_token_test.py -l 262144
zig build -Doptimize=ReleaseFast run -- "$@"
