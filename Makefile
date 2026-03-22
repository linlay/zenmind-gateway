VERSION ?= $(shell cat VERSION)
ARCH ?=

.PHONY: release

release:
	VERSION=$(VERSION) ARCH=$(ARCH) bash scripts/release.sh
