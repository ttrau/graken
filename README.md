# graken

A library and command line tool for flattening and validation of hierarchical and concurrent/parallel graphs (mainly `.scxml` state charts), written in crystal.
This library takes advantage of the graph's [ken](https://www.dictionary.com/browse/ken) (gra~~ph~~ken - the guard dependencies of parallel states in `.scxml`) to identify feasible edges and necessary triggers to reach a target state.

## Installation

Install crystal-lang

### Fedora / Centos

```sh
sudo dnf -y install gcc gcc-c++ gmp-devel libbsd-devel \
  libedit-devel libevent-devel libxml2-devel libyaml-devel \
  llvm-devel llvm-static libstdc++-static make \
  openssl-devel pcre-devel redhat-rpm-config \
  fonts-cmu

sudo dnf install snapd
sudo ln -s /var/lib/snapd/snap /snap
sudo snap install crystal --classic
```

### Debian / Ubuntu

```sh
sudo apt install gcc pkg-config git tzdata \
  libpcre3-dev libevent-dev libyaml-dev \
  libgmp-dev libssl-dev libxml2-dev libz-dev \
  fonts-cmu

sudo apt install snapd
sudo ln -s /var/lib/snapd/snap /snap
sudo snap install crystal --classic
```

### Install as library

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  graken:
    github: ttrau/graken
```

Run `shards install` and add `require "graken"` to your project.

### Install CLI

```sh
sudo make install
```

## Usage

### Usage CLI

```sh
graken < ./spec/simple.scxml                     ## pipe graph as .scxml file
graken -i ./spec/simple.scxml                    ## read graph from .scxml file
graken -s /tmp/graken.sock < ./spec/simple.scxml ## keep http service running with unix socket
graken -p 3000 < ./spec/simple.scxml             ## keep http service running behind port
graken -f < ./spec/simple.scxml                  ## flatten
graken -v < ./spec/simple.scxml                  ## flatten + validate
graken -h                                        ## show help
```

## Development

### Run

```sh
crystal src/cli.cr -v -o -a < spec/testmodel/simple.scxml
crystal src/cli.cr -v -o -a < spec/testmodel/cell.scxml
```

### Test

```sh
crystal spec
```

### Release

```sh
crystal build src/cli.cr --release
```

## Contributors

- [Thomas Trautner](https://github.com/ttrau) - creator and maintainer
