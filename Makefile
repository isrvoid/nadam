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

AUXFILES := Makefile README.md

.PHONY: all clean testdriver todolist
