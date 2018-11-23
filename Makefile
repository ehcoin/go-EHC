# This Makefile is meant to be used by people that do not usually work
# with Go source code. If you know what GOPATH is then you probably
# don't need to bother with make.

.PHONY: gehc android ios gehc-cross swarm evm all test clean
.PHONY: gehc-linux gehc-linux-386 gehc-linux-amd64 gehc-linux-mips64 gehc-linux-mips64le
.PHONY: gehc-linux-arm gehc-linux-arm-5 gehc-linux-arm-6 gehc-linux-arm-7 gehc-linux-arm64
.PHONY: gehc-darwin gehc-darwin-386 gehc-darwin-amd64
.PHONY: gehc-windows gehc-windows-386 gehc-windows-amd64

GOBIN = $(shell pwd)/build/bin
GO ?= latest

gehc:
	build/env.sh go run build/ci.go install ./cmd/gehc
	@echo "Done building."
	@echo "Run \"$(GOBIN)/gehc\" to launch gehc."

swarm:
	build/env.sh go run build/ci.go install ./cmd/swarm
	@echo "Done building."
	@echo "Run \"$(GOBIN)/swarm\" to launch swarm."

all:
	build/env.sh go run build/ci.go install

android:
	build/env.sh go run build/ci.go aar --local
	@echo "Done building."
	@echo "Import \"$(GOBIN)/gehc.aar\" to use the library."

ios:
	build/env.sh go run build/ci.go xcode --local
	@echo "Done building."
	@echo "Import \"$(GOBIN)/Gehc.framework\" to use the library."

test: all
	build/env.sh go run build/ci.go test

lint: ## Run linters.
	build/env.sh go run build/ci.go lint

clean:
	rm -fr build/_workspace/pkg/ $(GOBIN)/*

# The devtools target installs tools required for 'go generate'.
# You need to put $GOBIN (or $GOPATH/bin) in your PATH to use 'go generate'.

devtools:
	env GOBIN= go get -u golang.org/x/tools/cmd/stringer
	env GOBIN= go get -u github.com/kevinburke/go-bindata/go-bindata
	env GOBIN= go get -u github.com/fjl/gencodec
	env GOBIN= go get -u github.com/golang/protobuf/protoc-gen-go
	env GOBIN= go install ./cmd/abigen
	@type "npm" 2> /dev/null || echo 'Please install node.js and npm'
	@type "solc" 2> /dev/null || echo 'Please install solc'
	@type "protoc" 2> /dev/null || echo 'Please install protoc'

# Cross Compilation Targets (xgo)

gehc-cross: gehc-linux gehc-darwin gehc-windows gehc-android gehc-ios
	@echo "Full cross compilation done:"
	@ls -ld $(GOBIN)/gehc-*

gehc-linux: gehc-linux-386 gehc-linux-amd64 gehc-linux-arm gehc-linux-mips64 gehc-linux-mips64le
	@echo "Linux cross compilation done:"
	@ls -ld $(GOBIN)/gehc-linux-*

gehc-linux-386:
	build/env.sh go run build/ci.go xgo -- --go=$(GO) --targets=linux/386 -v ./cmd/gehc
	@echo "Linux 386 cross compilation done:"
	@ls -ld $(GOBIN)/gehc-linux-* | grep 386

gehc-linux-amd64:
	build/env.sh go run build/ci.go xgo -- --go=$(GO) --targets=linux/amd64 -v ./cmd/gehc
	@echo "Linux amd64 cross compilation done:"
	@ls -ld $(GOBIN)/gehc-linux-* | grep amd64

gehc-linux-arm: gehc-linux-arm-5 gehc-linux-arm-6 gehc-linux-arm-7 gehc-linux-arm64
	@echo "Linux ARM cross compilation done:"
	@ls -ld $(GOBIN)/gehc-linux-* | grep arm

gehc-linux-arm-5:
	build/env.sh go run build/ci.go xgo -- --go=$(GO) --targets=linux/arm-5 -v ./cmd/gehc
	@echo "Linux ARMv5 cross compilation done:"
	@ls -ld $(GOBIN)/gehc-linux-* | grep arm-5

gehc-linux-arm-6:
	build/env.sh go run build/ci.go xgo -- --go=$(GO) --targets=linux/arm-6 -v ./cmd/gehc
	@echo "Linux ARMv6 cross compilation done:"
	@ls -ld $(GOBIN)/gehc-linux-* | grep arm-6

gehc-linux-arm-7:
	build/env.sh go run build/ci.go xgo -- --go=$(GO) --targets=linux/arm-7 -v ./cmd/gehc
	@echo "Linux ARMv7 cross compilation done:"
	@ls -ld $(GOBIN)/gehc-linux-* | grep arm-7

gehc-linux-arm64:
	build/env.sh go run build/ci.go xgo -- --go=$(GO) --targets=linux/arm64 -v ./cmd/gehc
	@echo "Linux ARM64 cross compilation done:"
	@ls -ld $(GOBIN)/gehc-linux-* | grep arm64

gehc-linux-mips:
	build/env.sh go run build/ci.go xgo -- --go=$(GO) --targets=linux/mips --ldflags '-extldflags "-static"' -v ./cmd/gehc
	@echo "Linux MIPS cross compilation done:"
	@ls -ld $(GOBIN)/gehc-linux-* | grep mips

gehc-linux-mipsle:
	build/env.sh go run build/ci.go xgo -- --go=$(GO) --targets=linux/mipsle --ldflags '-extldflags "-static"' -v ./cmd/gehc
	@echo "Linux MIPSle cross compilation done:"
	@ls -ld $(GOBIN)/gehc-linux-* | grep mipsle

gehc-linux-mips64:
	build/env.sh go run build/ci.go xgo -- --go=$(GO) --targets=linux/mips64 --ldflags '-extldflags "-static"' -v ./cmd/gehc
	@echo "Linux MIPS64 cross compilation done:"
	@ls -ld $(GOBIN)/gehc-linux-* | grep mips64

gehc-linux-mips64le:
	build/env.sh go run build/ci.go xgo -- --go=$(GO) --targets=linux/mips64le --ldflags '-extldflags "-static"' -v ./cmd/gehc
	@echo "Linux MIPS64le cross compilation done:"
	@ls -ld $(GOBIN)/gehc-linux-* | grep mips64le

gehc-darwin: gehc-darwin-386 gehc-darwin-amd64
	@echo "Darwin cross compilation done:"
	@ls -ld $(GOBIN)/gehc-darwin-*

gehc-darwin-386:
	build/env.sh go run build/ci.go xgo -- --go=$(GO) --targets=darwin/386 -v ./cmd/gehc
	@echo "Darwin 386 cross compilation done:"
	@ls -ld $(GOBIN)/gehc-darwin-* | grep 386

gehc-darwin-amd64:
	build/env.sh go run build/ci.go xgo -- --go=$(GO) --targets=darwin/amd64 -v ./cmd/gehc
	@echo "Darwin amd64 cross compilation done:"
	@ls -ld $(GOBIN)/gehc-darwin-* | grep amd64

gehc-windows: gehc-windows-386 gehc-windows-amd64
	@echo "Windows cross compilation done:"
	@ls -ld $(GOBIN)/gehc-windows-*

gehc-windows-386:
	build/env.sh go run build/ci.go xgo -- --go=$(GO) --targets=windows/386 -v ./cmd/gehc
	@echo "Windows 386 cross compilation done:"
	@ls -ld $(GOBIN)/gehc-windows-* | grep 386

gehc-windows-amd64:
	build/env.sh go run build/ci.go xgo -- --go=$(GO) --targets=windows/amd64 -v ./cmd/gehc
	@echo "Windows amd64 cross compilation done:"
	@ls -ld $(GOBIN)/gehc-windows-* | grep amd64
