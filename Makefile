DOCKER_NAME=wscfront
DOCKER_TAG=latest
DOCKER_REPO=dcasnowdon

INFLUX_HOST ?= https://eastus-1.azure.cloud2.influxdata.com
INFLUX_ORG ?= BWSC
INFLUX_BUCKET ?= sample
QUERY_TIME ?= "-2d"1

GOOGLEMAPS_KEY ?= 

#ENV_VARS=INFLUX_URL INFLUX_ORG INFLUX_TOKEN INFLUX_BUCKET QUERY_TIME
ENV_VARS=INFLUX_TOKEN INFLUX_HOST INFLUX_ORG

export $(ENV_VARS)

.PHONY: build run

all: run

build:
	docker build -t $(DOCKER_NAME):$(DOCKER_TAG) .

bash: build
	docker run -p 5000:5000 $(foreach e,$(ENV_VARS),-e $(e)) -it $(DOCKER_NAME) bash

run: build
	mkdir -p results/
	docker run -p 5000:5000 $(foreach e,$(ENV_VARS),-e $(e)) -v $(PWD)/results:/app/results $(DOCKER_NAME)

publish: build
	docker image tag $(DOCKER_NAME):$(DOCKER_TAG) $(DOCKER_REPO)/$(DOCKER_NAME):$(DOCKER_TAG)
