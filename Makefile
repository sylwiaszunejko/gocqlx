all: check test

ifndef SCYLLA_VERSION
SCYLLA_VERSION := latest
endif

ifndef SCYLLA_CPU
SCYLLA_CPU := 0
endif

ifndef GOTEST_CPU
GOTEST_CPU := 1
endif

ifndef GOPATH
GOPATH := $(shell go env GOPATH)
endif

ifndef GOBIN
GOBIN := $(GOPATH)/bin
endif

.PHONY: fmt
fmt:
	@go fmt ./...

.PHONY: check
check:
	@$(GOBIN)/golangci-lint run ./...

.PHONY: fix
fix:
	@$(GOBIN)/golangci-lint run --fix ./...
	@fieldalignment -V=full >/dev/null 2>&1 || go install golang.org/x/tools/go/analysis/passes/fieldalignment/cmd/fieldalignment@v0.11.0
	@$(GOBIN)/fieldalignment -test=false -fix  ./...

GOTEST := go test -cpu $(GOTEST_CPU) -count=1 -cover -race -tags all

.PHONY: test
test:
	@$(GOTEST) .
	@$(GOTEST) ./qb
	@$(GOTEST) ./table
	@$(GOTEST) ./migrate
	@$(GOTEST) ./dbutil
	@$(GOTEST) ./cmd/schemagen

.PHONY: bench
bench:
	@go test -cpu $(GOTEST_CPU) -tags all -run=XXX -bench=. -benchmem ./...

.PHONY: run-examples
run-examples:
	@go test -tags all -v -run=Example ./...

.PHONY: run-scylla
run-scylla:
	@echo "==> Running test instance of Scylla $(SCYLLA_VERSION)"
	@docker pull scylladb/scylla:$(SCYLLA_VERSION)
	@docker run --name gocqlx-scylla -p 9042:9042 --cpuset-cpus=$(SCYLLA_CPU) --memory 1G --rm -d scylladb/scylla:$(SCYLLA_VERSION)
	@until docker exec gocqlx-scylla cqlsh -e "DESCRIBE SCHEMA"; do sleep 2; done

.PHONY: stop-scylla
stop-scylla:
	@docker stop gocqlx-scylla

.PHONY: get-deps
get-deps:
	@go mod download

define dl_tgz
	@curl -sSq -L $(2) | tar zxf - --strip 1 -C $(GOBIN) --wildcards '*/$(1)'
endef

.PHONY: get-tools
get-tools:
	@echo "==> Installing tools at $(GOBIN)..."
	@$(call dl_tgz,golangci-lint,https://github.com/golangci/golangci-lint/releases/download/v1.59.1/golangci-lint-1.59.1-linux-amd64.tar.gz)
