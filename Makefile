#
# GANTRY High-Assurance Cyber-Physical Automation Runtime
# Unified Build Automation and Verification Makefile
#
# Copyright (C) 2026 Aneesh Krishna. All rights reserved.
#

CC = clang
CFLAGS = -O3 -Wall -Wextra -fPIC -Iinclude
PYTHON = python3
EC = ec

.PHONY: all lib cli test test-eiffel test-c test-python bench clean help

all: lib cli

help:
	@echo "GANTRY Build Targets:"
	@echo "  make all          Build native C shared library and Eiffel CLI binary"
	@echo "  make lib          Compile build/libgantry.dylib shared library"
	@echo "  make cli          Compile bin/gantry native CLI executable"
	@echo "  make test         Execute all verification suites (Eiffel, C, Python)"
	@echo "  make test-eiffel  Execute 7-subsystem Eiffel Design by Contract test suite"
	@echo "  make test-c       Compile and run native C API test suite"
	@echo "  make test-python  Run Python SDK (pygantry) unit and plant simulation tests"
	@echo "  make bench        Run high-resolution microbenchmark performance scorecard"
	@echo "  make clean        Remove build artifacts, binaries, and temporary caches"

build:
	mkdir -p build

bin:
	mkdir -p bin

lib: build
	$(CC) $(CFLAGS) -shared -DGANTRY_BUILD_SHARED bindings/c/gantry_c_api.c -o build/libgantry.dylib

cli: bin
	$(EC) -batch -config gantry.ecf -target gantry -c_compile
	cp EIFGENs/gantry/W_code/gantry bin/gantry
	cp EIFGENs/gantry/W_code/gantry.melted bin/ 2>/dev/null || true

test: test-eiffel test-c test-python
	@echo "\n============================================================"
	@echo "       GANTRY UNIFIED VERIFICATION: ALL SUITES PASSED       "
	@echo "============================================================"

test-eiffel:
	$(EC) -batch -config gantry.ecf -target gantry_test -c_compile
	cd EIFGENs/gantry_test/W_code && ./gantry

test-c: lib build
	$(CC) $(CFLAGS) -Lbuild -lgantry tests/c/test_c_api.c -o build/test_c_api -Wl,-rpath,@executable_path
	./build/test_c_api

test-python: lib
	$(PYTHON) -m unittest discover -s tests/python -v

bench:
	$(EC) -batch -config gantry.ecf -target gantry_bench -c_compile
	cd EIFGENs/gantry_bench/W_code && ./gantry

clean:
	rm -rf build bin EIFGENs
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name "*.egg-info" -exec rm -rf {} +
