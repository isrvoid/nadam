MAKEFLAGS := -j 2
CFLAGS := -Weverything -Wno-padded -std=c11 -O1 -pthread -I../../include -L../..
CC := clang

example: run_a run_b

run_a: process_a process_b
	@./process_a

run_b: process_a process_b
	@./process_b

process_a: process_a.c connection.c
	@$(CC) $(CFLAGS) $^ ../../libnadamc.a -o $@

process_b: process_b.c connection.c
	@$(CC) $(CFLAGS) $^ ../../libnadamc.a -o $@

clean:
	-@$(RM) $(wildcard *.o *.obj *.exe process_a process_b)

.PHONY: example clean run_a run_b
