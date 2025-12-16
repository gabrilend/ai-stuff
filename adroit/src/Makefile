# {{{ Makefile for Adroit RPG project
CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -g -pthread
LDFLAGS = -lraylib -lpthread -lm -ldl

# {{{ Lua integration options
# For standard Lua
LUA_CFLAGS = -DLUA_VERSION
LUA_LDFLAGS = -llua5.4

# For LuaJIT (recommended for performance)
LUAJIT_CFLAGS = -DLUAJIT_VERSION
LUAJIT_LDFLAGS = -lluajit-5.1

# Default to LuaJIT if available, otherwise standard Lua
ifeq ($(shell pkg-config --exists luajit && echo "yes"), yes)
    LUA_CFLAGS = $(LUAJIT_CFLAGS)
    LUA_LDFLAGS = $(LUAJIT_LDFLAGS)
    $(info Using LuaJIT for integration)
else ifeq ($(shell pkg-config --exists lua5.4 && echo "yes"), yes)
    LUA_CFLAGS = $(LUA_CFLAGS)
    LUA_LDFLAGS = $(LUA_LDFLAGS)
    $(info Using standard Lua for integration)
else
    $(info No Lua library detected - integration will use stub implementation)
endif
# }}}

# {{{ Directories
SRCDIR = src
OBJDIR = obj
LIBDIR = libs
# }}}

# {{{ Source files
SOURCES = $(wildcard $(SRCDIR)/*.c) $(wildcard $(LIBDIR)/common/*.c) $(wildcard $(LIBDIR)/integration/*.c)
OBJECTS = $(SOURCES:%.c=$(OBJDIR)/%.o)
TARGET = adroit
# }}}

# {{{ Main targets
all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(OBJECTS) -o $@ $(LDFLAGS) $(LUA_LDFLAGS)

$(OBJDIR)/%.o: %.c | $(OBJDIR)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(LUA_CFLAGS) -I$(SRCDIR) -I$(LIBDIR) -c $< -o $@

$(OBJDIR):
	mkdir -p $(OBJDIR)
	mkdir -p $(OBJDIR)/$(SRCDIR)
	mkdir -p $(OBJDIR)/$(LIBDIR)/common
	mkdir -p $(OBJDIR)/$(LIBDIR)/integration
# }}}

# {{{ Utility targets
clean:
	rm -rf $(OBJDIR) $(TARGET) lua_test lua_test_luajit lua_test_std

rebuild: clean all

test: $(TARGET)
	./$(TARGET)

# {{{ Lua test targets
lua-test: lua_test
	./lua_test

lua_test: lua_test.c $(LIBDIR)/common/logging.c $(LIBDIR)/integration/lua_bridge.c
	$(CC) $(CFLAGS) $(LUA_CFLAGS) -I$(LIBDIR) $^ -o $@ -lpthread $(LUA_LDFLAGS)

lua-test-force-luajit: lua_test_luajit
	./lua_test_luajit

lua_test_luajit: lua_test.c $(LIBDIR)/common/logging.c $(LIBDIR)/integration/lua_bridge.c
	$(CC) $(CFLAGS) $(LUAJIT_CFLAGS) -I$(LIBDIR) $^ -o $@ -lpthread $(LUAJIT_LDFLAGS)

lua-test-force-std: lua_test_std
	./lua_test_std

lua_test_std: lua_test.c $(LIBDIR)/common/logging.c $(LIBDIR)/integration/lua_bridge.c
	$(CC) $(CFLAGS) -DLUA_VERSION -I$(LIBDIR) $^ -o $@ -lpthread $(LUA_LDFLAGS)
# }}}

debug: CFLAGS += -DDEBUG -O0
debug: $(TARGET)

release: CFLAGS += -O2 -DNDEBUG
release: $(TARGET)
# }}}

# {{{ Installation
install: $(TARGET)
	cp $(TARGET) /usr/local/bin/

uninstall:
	rm -f /usr/local/bin/$(TARGET)
# }}}

.PHONY: all clean rebuild test debug release install uninstall lua-test lua-test-force-luajit lua-test-force-std
# }}}