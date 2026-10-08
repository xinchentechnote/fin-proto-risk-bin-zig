PROTO_DSL := proto/risk_v0.2.0.pdsl
OUTPUT_DIR := src/
FIN_PROTOC ?= $(HOME)/workspace/fin-protoc/bin/fin-protoc

.PHONY: compile test all

compile:
	$(FIN_PROTOC) -f $(PROTO_DSL) -z $(OUTPUT_DIR)

test: compile
	zig build test

all: test
