MAKEFLAGS := -j 2
NADAMCDIR := ../build
NADAMCINCLUDE := ../include
SRCCDIR := src
BUILDDIR := build
CFLAGS := -Weverything -Wno-padded -std=c11 -O1 -pthread -I$(NADAMCINCLUDE) -L$(NADAMCDIR) -lnadamc
CC := clang

examplec: runc_a runc_b

runc_a: $(BUILDDIR)/processc_a
	@$<

# B can't run much earlier than A because A creates communication pipes
runc_b: $(BUILDDIR)/processc_b $(BUILDDIR)/processc_a
	@$<

$(BUILDDIR)/processc_a: $(SRCCDIR)/process_a.c $(SRCCDIR)/connection.c
	@$(CC) $(CFLAGS) $^ -o $@

$(BUILDDIR)/processc_b: $(SRCCDIR)/process_b.c $(SRCCDIR)/connection.c
	@$(CC) $(CFLAGS) $^ -o $@

clean:
	-@$(RM) $(wildcard $(BUILDDIR)/*)
