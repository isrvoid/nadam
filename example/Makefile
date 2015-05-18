MAKEFLAGS := -j 2

NADAMCDIR := ../build
NADAMCINCLUDE := ../include

CSRCDIR := src

BUILDDIR := build

CFLAGS := -Weverything -Wno-padded -std=c11 -O1 -pthread -I$(NADAMCINCLUDE) -L$(NADAMCDIR) -lnadamc
CC := clang

CExample: runCProcessA runCProcessB

runCProcessA: $(BUILDDIR)/CProcessA
	@$<

# B can't run much earlier than A because A needs to create communication pipes
runCProcessB: $(BUILDDIR)/CProcessB $(BUILDDIR)/CProcessA
	@$<

$(BUILDDIR)/CProcessA: $(CSRCDIR)/processA.c $(CSRCDIR)/connection.c
	@$(CC) $^ $(CFLAGS) -o $@

$(BUILDDIR)/CProcessB: $(CSRCDIR)/processB.c $(CSRCDIR)/connection.c
	@$(CC) $^ $(CFLAGS) -o $@

clean:
	-@$(RM) $(wildcard $(BUILDDIR)/*)
