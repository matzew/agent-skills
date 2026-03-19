IMAGE ?= quay.io/matzew/agent-skills
TAG ?= latest

.PHONY: build push all

all: build push

build:
	podman build -t $(IMAGE):$(TAG) -f Containerfile .

push:
	podman push $(IMAGE):$(TAG)
