CRYSTAL = crystal
CRFLAGS = --progress --warnings all
BINDIR = /usr/local/bin
APP = graken
APPDIR = src/cli.cr
BENCHDIR = src/bench.cr

install: clean
	shards install
	@mkdir -p $(BINDIR)
		$(CRYSTAL) build $(APPDIR) --release -o $(BINDIR)/$(APP) $(CRFLAGS)

devel: clean
	@mkdir -p $(BINDIR)
		$(CRYSTAL) build $(APPDIR) --debug -o $(BINDIR)/$(APP) $(CRFLAGS)

clean:
	rm -f "$(BINDIR)/$(APP)"

benchmark:
	$(CRYSTAL) run --release $(BENCHDIR)
