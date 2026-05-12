# Local-dev wrapper around `docker build` / `docker run` for zephyr_ncs_bundle.
# Run from the docker/ directory: `make image`, `make build BOARD=... APP=...`.

NCS_VERSION   ?= 3.3.0
CFG_REV       ?= 1.0
ZSDK_VERSION  ?=
INCLUDE_VPR   ?= 0
JFROG_VERSION ?= 2.103.0
IMAGE         ?= zephyr_ncs_bundle
TAG           := $(IMAGE):$(NCS_VERSION)-$(CFG_REV)

BOARD        ?=
APP          ?= .
WORKDIR_HOST ?= $(abspath $(CURDIR)/..)
ARTIFACTS    ?= $(WORKDIR_HOST)/artifacts
CCACHE       ?= $(HOME)/.cache/zephyr-ccache

DOCKER       ?= docker
DOCKER_BUILD ?= DOCKER_BUILDKIT=1 $(DOCKER) build
# Only allocate a TTY when stdin is one (interactive shell). In CI / piped
# contexts `docker run -it` fails with "the input device is not a TTY".
TTY          := $(shell test -t 0 && echo "-it")
DOCKER_RUN   ?= $(DOCKER) run --rm $(TTY)

.PHONY: image build test shell clean print-tag

image:
	$(DOCKER_BUILD) \
	    --build-arg NCS_REVISION=v$(NCS_VERSION) \
	    $(if $(ZSDK_VERSION),--build-arg ZSDK_VERSION=$(ZSDK_VERSION),) \
	    --build-arg INCLUDE_VPR=$(INCLUDE_VPR) \
	    --build-arg JFROG_VERSION=$(JFROG_VERSION) \
	    -t $(TAG) .

build:
	@test -n "$(BOARD)" || (echo "BOARD= is required (e.g. BOARD=nrf5340dk/nrf5340/cpuapp)"; exit 2)
	@mkdir -p "$(ARTIFACTS)" "$(CCACHE)"
	$(DOCKER_RUN) \
	    -v "$(WORKDIR_HOST)":/workdir \
	    -v "$(ARTIFACTS)":/artifacts \
	    -v "$(CCACHE)":/ccache \
	    -e BOARD="$(BOARD)" \
	    -e APP="$(APP)" \
	    $(TAG) build

test:
	@mkdir -p "$(ARTIFACTS)"
	$(DOCKER_RUN) \
	    -v "$(WORKDIR_HOST)":/workdir \
	    -v "$(ARTIFACTS)":/artifacts \
	    $(TAG) test

shell:
	$(DOCKER_RUN) \
	    -v "$(WORKDIR_HOST)":/workdir \
	    -v "$(CCACHE)":/ccache \
	    $(TAG) shell

clean:
	rm -rf "$(WORKDIR_HOST)/build" "$(ARTIFACTS)"

print-tag:
	@echo $(TAG)
