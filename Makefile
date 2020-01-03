Version := $(shell git describe --tags --dirty)
GitCommit := $(shell git rev-parse HEAD)
LDFLAGS := "-s -w -X main.Version=$(Version) -X main.GitCommit=$(GitCommit)"
CONTAINERD_VER := 1.3.2
FAASD_VER := 0.4.0

.PHONY: all
all: local

local:
	CGO_ENABLED=0 GOOS=linux go build -o bin/faasd

.PHONY: dist
dist:
	CGO_ENABLED=0 GOOS=linux go build -ldflags $(LDFLAGS) -a -installsuffix cgo -o bin/faasd
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build -ldflags $(LDFLAGS) -a -installsuffix cgo -o bin/faasd-armhf
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags $(LDFLAGS) -a -installsuffix cgo -o bin/faasd-arm64

.PHONY: prepare-test
prepare-test:
	curl -sLSf https://github.com/containerd/containerd/releases/download/v$(CONTAINERD_VER)/containerd-$(CONTAINERD_VER).linux-amd64.tar.gz > /tmp/containerd.tar.gz && sudo tar -xvf /tmp/containerd.tar.gz -C /usr/local/bin/ --strip-components=1
	curl -SLfs https://raw.githubusercontent.com/containerd/containerd/v1.3.2/containerd.service | sudo tee /etc/systemd/system/containerd.service
	sudo systemctl daemon-reload && sudo systemctl start containerd
	sudo curl -fSLs "https://github.com/genuinetools/netns/releases/download/v0.5.3/netns-linux-arm" --output "/usr/local/bin/netns" && sudo chmod a+x "/usr/local/bin/netns"
	sudo /sbin/sysctl -w net.ipv4.conf.all.forwarding=1
	sudo curl -sSLf "https://github.com/alexellis/faas-containerd/releases/download/$(FAASD_VER)/faas-containerd" --output "/usr/local/bin/faas-containerd" && sudo chmod a+x "/usr/local/bin/faas-containerd" || :
	cd $(HOME)/go/src/github.com/alexellis/faasd/ && sudo ./faasd install
	sudo systemctl status containerd --no-pager
	sudo systemctl status faas-containerd --no-pager
	sudo systemctl status faasd --no-pager
	curl -SLfs https://cli.openfaas.com | sudo sh

.PHONY: test-e2e
test-e2e:
	sudo cat $(HOME)/go/src/github.com/alexellis/faasd/basic-auth-password | faas-cli login --password-stdin
	faas-cli store deploy figlet
	faas-cli list -v
	uname | faas-cli invoke figlet
	faas-cli delete figlet
	faas-cli list -v