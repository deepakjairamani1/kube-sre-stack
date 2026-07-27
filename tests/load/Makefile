# Load Testing — Run with: make <target>
#
# Prerequisites: k6 installed (https://k6.io/docs/get-started/installation/)
# Override BASE_URL for different environments

BASE_URL ?= http://localhost:4000
RESULTS_DIR := results

.PHONY: all gateway auth soak clean help

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

all: gateway auth ## Run all standard load tests (excludes soak)

gateway: ## Run gateway load test (8 min, up to 150 VUs)
	@mkdir -p $(RESULTS_DIR)
	k6 run \
		-e BASE_URL=$(BASE_URL) \
		--out json=$(RESULTS_DIR)/gateway-metrics.json \
		gateway-load-test.js

auth: ## Run auth spike test (4 min, spike to 100 rps)
	@mkdir -p $(RESULTS_DIR)
	k6 run \
		-e BASE_URL=$(BASE_URL) \
		--out json=$(RESULTS_DIR)/auth-metrics.json \
		auth-spike-test.js

soak: ## Run soak test (30 min, steady 50 VUs — run before releases)
	@mkdir -p $(RESULTS_DIR)
	k6 run \
		-e BASE_URL=$(BASE_URL) \
		--out json=$(RESULTS_DIR)/soak-metrics.json \
		soak-test.js

clean: ## Remove test results
	rm -rf $(RESULTS_DIR)

# Environment-specific targets
test-dev: ## Run against dev environment
	$(MAKE) all BASE_URL=https://dev.piggymetrics.example.com

test-staging: ## Run against staging (pre-prod validation)
	$(MAKE) all BASE_URL=https://staging.piggymetrics.example.com

test-prod-canary: ## Run lightweight test against prod canary
	k6 run \
		-e BASE_URL=https://canary.piggymetrics.example.com \
		--vus 5 --duration 2m \
		gateway-load-test.js
