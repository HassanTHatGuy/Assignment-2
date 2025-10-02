# Makefile for tcp_client (Ubuntu x86-64, NASM)
# Targets:
#   make            -> build tcp_client
#   make run        -> run client (PORT, MSG configurable)
#   make server     -> run Python test server
#   make test       -> launch server, run client, stop server, show log
#   make clean      -> remove build artifacts
#
# Override: make PORT=6000 MSG="hello\n" run

NASM      ?= nasm
ASFLAGS   ?= -felf64 -g -F dwarf
CC        ?= gcc
LDFLAGS   ?= -nostartfiles -no-pie
PY        ?= python3

SRC       ?= tcp_client.asm
OBJ       ?= $(SRC:.asm=.o)
BIN       ?= tcp_client

PORT      ?= 5000
MSG       ?= hello

.PHONY: all clean run server test

all: $(BIN)

$(BIN): $(OBJ)
	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.asm
	$(NASM) $(ASFLAGS) $< -o $@

run: $(BIN)
	@echo "Running client -> 127.0.0.1:$(PORT) msg='$(MSG)'"
	./$(BIN) $(PORT) "$(MSG)"

server: server.py
	@echo "Starting server on 127.0.0.1:$(PORT) ..."
	$(PY) server.py $(PORT)

test: $(BIN) server.py
	@echo "Launching background server on 127.0.0.1:$(PORT) ..."
	@($(PY) server.py $(PORT) > server.out 2>&1 &) ; echo $$! > .server.pid
	@sleep 0.2
	@echo "Client says: $(MSG)"
	@./$(BIN) $(PORT) "$(MSG)"
	@echo "Stopping server..."
	@kill `cat .server.pid` 2>/dev/null || true
	@rm -f .server.pid
	@echo "Server log:"
	@tail -n +1 server.out || true

clean:
	rm -f $(BIN) $(OBJ) server.out .server.pid
