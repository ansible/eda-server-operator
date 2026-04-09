# operator.mk — EDA Server Operator specific targets and variables
#
# This file is NOT synced across repos. Each operator maintains its own.

#@ Operator Variables

VERSION ?= $(shell git describe --tags 2>/dev/null || echo 0.0.1)
IMAGE_TAG_BASE ?= quay.io/ansible/eda-server-operator
NAMESPACE ?= eda
DEPLOYMENT_NAME ?= eda-server-operator-controller-manager

# Dev CR applied by _eda-apply-cr with URL substitution (not by common DEV_CR mechanism)
_EDA_DEV_CR ?= dev/eda-cr/eda-openshift-cr.yml

# AWX connection (required for EDA)
AUTOMATION_SERVER_URL ?=
AWX_NAMESPACE ?= awx

# Custom configs to apply during post-deploy (secrets, configmaps, etc.)
DEV_CUSTOM_CONFIG ?= dev/secrets/admin-password-secret.yml dev/secrets/custom-pg-secret.yml dev/secrets/custom-db-fields-encryption-secret.yml

# Feature flags
BUILD_IMAGE ?= true
CREATE_CR ?= true

# Teardown configuration
TEARDOWN_CR_KINDS ?= eda
TEARDOWN_BACKUP_KINDS ?= edabackup
TEARDOWN_RESTORE_KINDS ?= edarestore
OLM_SUBSCRIPTIONS ?=

##@ EDA Server Operator

.PHONY: operator-up
operator-up: _operator-build-and-push _operator-deploy _operator-wait-ready _operator-post-deploy _eda-apply-cr ## EDA-specific deploy
	@:

.PHONY: _eda-apply-cr
_eda-apply-cr:
	@if [ "$(CREATE_CR)" != "true" ] || [ ! -f "$(_EDA_DEV_CR)" ]; then exit 0; fi
	@if [ -z "$(AUTOMATION_SERVER_URL)" ]; then \
		echo "ERROR: AUTOMATION_SERVER_URL is required. Set it or run 'make awx-url AWX_NAMESPACE=<ns>' to discover it." >&2; \
		exit 1; \
	fi
	@echo "Applying dev CR: $(_EDA_DEV_CR) (automation_server_url=$(AUTOMATION_SERVER_URL))"
	@sed 's|https://awx.example.com|$(AUTOMATION_SERVER_URL)|g' $(_EDA_DEV_CR) | $(KUBECTL) apply -n $(NAMESPACE) -f -

.PHONY: awx-url
awx-url: ## Discover AWX route URL (use AWX_NAMESPACE to set namespace, default: awx)
	@URL=$$($(KUBECTL) get route -n $(AWX_NAMESPACE) -l app.kubernetes.io/managed-by=awx-operator \
		-o jsonpath='https://{.items[0].spec.host}' 2>/dev/null); \
	if [ -z "$$URL" ] || [ "$$URL" = "https://" ]; then \
		echo "ERROR: No AWX route found in namespace $(AWX_NAMESPACE)" >&2; \
		exit 1; \
	fi; \
	echo "$$URL"

##@ Release

.PHONY: generate-operator-yaml
generate-operator-yaml: kustomize ## Generate operator.yaml with image tag $(VERSION)
	@cd config/manager && $(KUSTOMIZE) edit set image controller=quay.io/ansible/eda-server-operator:${VERSION}
	@$(KUSTOMIZE) build config/default > ./operator.yaml
	@echo "Generated operator.yaml with image tag $(VERSION)"
