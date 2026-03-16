# Makefile for Physics Simulator - Pachinko Machine
# Compiles C source files and links with raylib, pthreads, and system libraries

CC = gcc
CFLAGS = -Wall -Wextra -std=c11 -I./src
LDFLAGS = -lraylib -lm -lpthread

# Linux-specific libraries for raylib
LDFLAGS += -lGL -ldl -lrt -lX11

SRC = $(wildcard src/*.c)
OBJ = $(SRC:.c=.o)
BIN = bin/physics-sim

ifdef DEBUG
    CFLAGS += -g -O0 -DDEBUG
else
    CFLAGS += -O2
endif

all: $(BIN)

$(BIN): $(OBJ)
	@mkdir -p bin
	$(CC) $(OBJ) -o $(BIN) $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

run: $(BIN)
	./$(BIN)

clean:
	rm -f src/*.o $(BIN)

.PHONY: all run clean
