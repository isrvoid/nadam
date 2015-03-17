DROOTDIR := nadam
TYPEGENDIR := $(DROOTDIR)/typegen
TYPEGENSRC := $(shell find $(TYPEGENDIR) -type f -name "*.d") $(DROOTDIR)/types.d

CROOTDIR := src
CSRC := $(shell find $(CROOTDIR) -type f -name "*.c")

DFLAGS := -O -release -boundscheck=off
DTESTFLAGS := -unittest

CWARNINGS := -Wall -Wextra -pedantic -Wshadow -Wpointer-arith -Wcast-align \
	-Wwrite-strings -Wmissing-prototypes -Wmissing-declarations \
	-Wredundant-decls -Wnested-externs -Winline -Wno-long-long \
	-Wuninitialized -Wconversion -Wstrict-prototypes
CFLAGS := -std=c11 -O3 $(CWARNINGS)
CTESTFLAGS := -std=c11 $(CWARNINGS)

all: typegen

typegen: $(TYPEGENSRC)
	@dmd $(TYPEGENSRC) -of$@ $(DFLAGS)

typegen_t: $(TYPEGENSRC)
	@dmd $(TYPEGENSRC) -of$@ $(DTESTFLAGS)

nadamC: $(CSRC)
	@$(CC) $(CSRC) $(CFLAGS) -o $@

nadamC_t: $(CSRC)
	@$(CC) $(CSRC) $(CTESTFLAGS) -o $@

clean:
	-@$(RM) $(wildcard *.o *_t.o *_t) typegen nadamC

TESTFILES := typegen_t nadamC_t

unittest: $(TESTFILES)
	-@rc=0; count=0; \
		for file in $(TESTFILES); do \
		echo " TEST      $$file"; ./$$file; \
		rc=`expr $$rc + $$?`; count=`expr $$count + 1`; \
		done; \
		echo; echo "Tests executed: $$count   Tests failed: $$rc"

AUXFILES := Makefile README.md

.PHONY: all clean unittest todolist
