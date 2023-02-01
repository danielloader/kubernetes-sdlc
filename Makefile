EXECUTABLES = flux kubectl docker
K := $(foreach exec,$(EXECUTABLES),\
        $(if $(shell which $(exec)),some string,$(error "No $(exec) in PATH")))

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

build:
	@for d in $(ROOT_DIR)/containers/*/; do \
		docker build -t local/$$(basename $$d):latest $$d; \
	done