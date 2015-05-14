GENNMISRC := nadam/infogen/generator.d nadam/infogen/parser.d nadam/types.d

CSRCDIR := src
NADAMCINCLUDE := include
NADAMCSRC := $(CSRCDIR)/nadam.c

BUILDDIR := build

DFLAGS := -release -O -boundscheck=off
DFLAGS_T := -unittest

CC := clang
CWARNINGS := -Weverything -Wno-padded -Wno-unused-function \
	-Wno-reserved-id-macro -Wno-unused-parameter
COMMON_CFLAGS := -std=c11 $(CWARNINGS) -I$(NADAMCINCLUDE) -pthread
CFLAGS := $(COMMON_CFLAGS) -O3
CFLAGS_T := $(COMMON_CFLAGS) -O1 -Wno-missing-prototypes -DUNITTEST

$(BUILDDIR)/gennmi: $(GENNMISRC)
	@dmd $(DFLAGS) $(GENNMISRC) -of$@

$(BUILDDIR)/gennmi_t: $(GENNMISRC)
	@dmd $(DFLAGS_T) $(GENNMISRC) -of$@

$(BUILDDIR)/libnadamc.a: $(BUILDDIR)/nadamc.o
	@ar rcs $@ $<

$(BUILDDIR)/nadamc.o: $(NADAMCSRC)
	@$(CC) $(CFLAGS) $(NADAMCSRC) -c -o $@

$(BUILDDIR)/nadamc_t: $(BUILDDIR)/nadamc_t.c
	@$(CC) $(CFLAGS_T) $(NADAMCSRC) $< -o $@

$(BUILDDIR)/nadamc_t.c: $(NADAMCSRC)
	@gendsu $(NADAMCSRC) -of$@

clean:
	-@$(RM) $(wildcard $(BUILDDIR)/*)

AUXFILES := Makefile README.md

.PHONY: clean
