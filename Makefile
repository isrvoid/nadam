all: typegen

DROOTDIR := nadam
TYPEGENDIR := $(DROOTDIR)/typegen
TYPEGENSRC := $(shell find $(TYPEGENDIR) -type f -name "*.d") $(DROOTDIR)/types.d

DMDFLAGS := -O
DMDTESTFLAGS := -unittest

all: typegen

typegen: $(TYPEGENSRC)
	@dmd $(TYPEGENSRC) -of$@ $(DMDFLAGS)

typegen_t: $(TYPEGENSRC)
	@dmd $(TYPEGENSRC) -of$@ $(DMDTESTFLAGS)

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
