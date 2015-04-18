DROOTDIR := nadam
TYPEGENDIR := $(DROOTDIR)/typegen
TYPEGENSRC := $(shell find $(TYPEGENDIR) -type f -name "*.d") $(DROOTDIR)/types.d

CROOTDIR := src
NADAMCSRC := $(shell find $(CROOTDIR) -type f -name "*.c")

DFLAGS := -O -release -boundscheck=off
DTESTFLAGS := -unittest

CWARNINGS := -Wall -Wextra -pedantic -Wshadow -Wpointer-arith -Wcast-align \
	-Wwrite-strings -Wmissing-prototypes -Wmissing-declarations \
	-Wredundant-decls -Wnested-externs -Winline -Wno-long-long \
	-Wuninitialized -Wconversion -Wstrict-prototypes
CFLAGS := -std=c11 -O3 $(CWARNINGS)
CTESTFLAGS := -std=c11 -O1 $(CWARNINGS) -DUNITTEST

all: typegen

typegen: $(TYPEGENSRC)
	@dmd $(TYPEGENSRC) -of$@ $(DFLAGS)

typegen_t: $(TYPEGENSRC)
	@dmd $(TYPEGENSRC) -of$@ $(DTESTFLAGS)

nadamc: $(NADAMCSRC)
	@$(CC) $(NADAMCSRC) $(CFLAGS) -o $@

nadamc_t: nadamc_t.c
	@$(CC) $(NADAMCSRC) $< $(CTESTFLAGS) -o $@

nadamc_t.c: $(NADAMCSRC)
	@gendsu $(NADAMCSRC) -of$@

clean:
	-@$(RM) $(wildcard *.o *_t.o *_t typegen nadamc nadam_t.c)

TESTFILES := typegen_t nadamc_t

testAll: $(TESTFILES)
	-@rc=0; count=0; \
		for file in $(TESTFILES); do \
		echo " TEST      $$file"; ./$$file; \
		rc=`expr $$rc + $$?`; count=`expr $$count + 1`; \
		done; \
		echo; echo "Tests executed: $$count   Tests failed: $$rc"

AUXFILES := Makefile README.md

.PHONY: all clean todolist
