DROOTDIR := nadam
TYPEGENDIR := $(DROOTDIR)/typegen
TYPEGENSRC := $(shell find $(TYPEGENDIR) -type f -name "*.d") $(DROOTDIR)/types.d

CROOTDIR := src
CINCLUDEDIR := include
NADAMCSRC := $(shell find $(CROOTDIR) -type f -name "*.c")

DFLAGS := -release -O -boundscheck=off
DTESTFLAGS := -unittest

CC := clang
# FIXME remove -Wno-unused-parameter if functions are implemented
CWARNINGS := -Weverything -Wno-padded -Wno-unused-parameter \
	-Wno-unused-function -Wno-reserved-id-macro
COMMON_CFLAGS := -std=c11 $(CWARNINGS) -I$(CINCLUDEDIR) -pthread
CFLAGS := $(COMMON_CFLAGS) -O3
CFLAGS_T := $(COMMON_CFLAGS) -O1 -Wno-missing-prototypes -DUNITTEST

default: nadamc

typegen: $(TYPEGENSRC)
	@dmd $(TYPEGENSRC) -of$@ $(DFLAGS)

typegen_t: $(TYPEGENSRC)
	@dmd $(TYPEGENSRC) -of$@ $(DTESTFLAGS)

nadamc: $(NADAMCSRC)
	@$(CC) $(CFLAGS) $(NADAMCSRC) -o $@

nadamc_t: nadamc_t.c
	@$(CC) $(CFLAGS_T) $(NADAMCSRC) $< -o $@

nadamc_t.c: $(NADAMCSRC)
	@gendsu $(NADAMCSRC) -of$@

clean:
	-@$(RM) $(wildcard *.o *.obj *_t *.exe typegen nadamc nadamc_t.c)

AUXFILES := Makefile README.md

.PHONY: default clean
