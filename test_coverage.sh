#!/usr/bin/env bash

# based on https://hannes.kaeufler.net/posts/measuring-code-coverage-in-crystal-with-kcov

echo "require \"./spec/*\"" > run_tests.cr && \
crystal build run_tests.cr -D skip-integration && \
kcov --clean --include-path=$(pwd)/src $(pwd)/coverage ./run_tests #&& \
bash <(curl -s https://codecov.io/bash) -s $(pwd)/coverage