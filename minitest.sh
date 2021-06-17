echo "require \"./test/coverage_test\"" > minitest.cr && \
crystal build minitest.cr -D skip-integration && \
kcov --clean --include-path=$(pwd)/test/coverage_test $(pwd)/test/coverage ./minitest