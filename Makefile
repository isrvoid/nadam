DROOTDIR := nadam
TYPEGENDIR := $(DROOTDIR)/typegen
TYPEGENSRC := $(shell find $(TYPEGENDIR) -type f -name "*.d") $(DROOTDIR)/types.d

DFLAGS := -O -release -boundscheck=off
DTESTFLAGS := -unittest

all: typegen

typegen: $(TYPEGENSRC)
	@dmd $(TYPEGENSRC) -of$@ $(DFLAGS)

typegen_t: $(TYPEGENSRC)
	@dmd $(TYPEGENSRC) -of$@ $(DTESTFLAGS)

clean:
	-@$(RM) $(wildcard *.o *_t.o *_t) typegen

TESTFILES := typegen_t

unittest: $(TESTFILES)
	-@rc=0; count=0; \
		for file in $(TESTFILES); do \
		echo " TEST      $$file"; ./$$file; \
		rc=`expr $$rc + $$?`; count=`expr $$count + 1`; \
		done; \
		echo; echo "Tests executed: $$count   Tests failed: $$rc"

AUXFILES := Makefile README.md

.PHONY: all clean unittest todolist
