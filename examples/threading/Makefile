STDLIB := \
		../../standard/src/Tuples.aui,../../standard/src/Tuples.aum \
		../../standard/src/Bounded.aui,../../standard/src/Bounded.aum \
		../../standard/src/Equality.aui,../../standard/src/Equality.aum \
		../../standard/src/Order.aui,../../standard/src/Order.aum \
		../../standard/src/Box.aui,../../standard/src/Box.aum \
		../../standard/src/Buffer.aui,../../standard/src/Buffer.aum \
		../../standard/src/String.aui,../../standard/src/String.aum \
		../../standard/src/StringBuilder.aui,../../standard/src/StringBuilder.aum \
		../../standard/src/IO/IO.aui,../../standard/src/IO/IO.aum \
		../../standard/src/IO/Terminal.aui,../../standard/src/IO/Terminal.aum \
		../../standard/src/System/Thread.aui,../../standard/src/System/Thread.aum \
		../../standard/src/System/Thread/Pool.aui,../../standard/src/System/Thread/Pool.aum \

PROG := ThreadDemo
ENTRY := Demo.Threads:main
SRC := $(PROG).aui,$(PROG).aum
OUT_C := thread_demo.c
OUT_BIN := thread_demo
CC ?= cc
CFLAGS ?= -fwrapv -pthread
LDLIBS ?= -lm -pthread

.DEFAULT: all
all: $(OUT_BIN)

$(OUT_C): $(PROG).aui $(PROG).aum
	../../austral compile $(STDLIB) $(SRC) --entrypoint=$(ENTRY) --target-type=c --output=$(OUT_C)

$(OUT_BIN): $(OUT_C) ../../standard/src/System/thread_support.c
	$(CC) $(CFLAGS) $(OUT_C) ../../standard/src/System/thread_support.c $(LDLIBS) -o $(OUT_BIN)

.PHONY: run clean
run: $(OUT_BIN)
	./$(OUT_BIN)

clean:
	rm -f $(OUT_C) $(OUT_BIN)
