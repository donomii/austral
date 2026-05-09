MODULES := \
		src/Tuples.aui,src/Tuples.aum \
		src/Bounded.aui,src/Bounded.aum \
		src/Equality.aui,src/Equality.aum \
		src/Order.aui,src/Order.aum \
		src/Box.aui,src/Box.aum \
		src/Buffer.aui,src/Buffer.aum \
		src/String.aui,src/String.aum \
		src/StringBuilder.aui,src/StringBuilder.aum \
		src/IO/IO.aui,src/IO/IO.aum \
		src/IO/Terminal.aui,src/IO/Terminal.aum \
		src/System/Thread.aui,src/System/Thread.aum \
		src/System/Thread/Pool.aui,src/System/Thread/Pool.aum \
		test/Unit.aui,test/Unit.aum \
		test/Tuples.aui,test/Tuples.aum \
		test/Bounded.aui,test/Bounded.aum \
		test/Equality.aui,test/Equality.aum \
		test/Order.aui,test/Order.aum \
		test/Box.aui,test/Box.aum \
		test/Buffer.aui,test/Buffer.aum \
		test/String.aui,test/String.aum \
		test/StringBuilder.aui,test/StringBuilder.aum \
		test/IO/Terminal.aui,test/IO/Terminal.aum \
		test/System/Thread.aui,test/System/Thread.aum \
		test/Main.aui,test/Main.aum
TEST_BIN := test_bin
TEST_C := test_bin.c
CC ?= cc
CFLAGS ?= -fwrapv -pthread
LDLIBS ?= -lm -pthread

.DEFAULT: all
all: $(TEST_BIN)

$(TEST_C): src/*.aui src/*.aum src/*/*.aui src/*/*.aum src/*/*/*.aui src/*/*/*.aum test/*.aui test/*.aum test/*/*.aui test/*/*.aum
	../austral compile $(MODULES) --entrypoint=Standard.Test:Main --target-type=c --output=$(TEST_C)

$(TEST_BIN): $(TEST_C) src/System/thread_support.c
	$(CC) $(CFLAGS) $(TEST_C) src/System/thread_support.c $(LDLIBS) -o $(TEST_BIN)

.PHONY: clean
clean:
	-test -f $(TEST_BIN) && rm $(TEST_BIN)
	-test -f $(TEST_C) && rm $(TEST_C)
