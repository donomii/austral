.PHONY: all
all:
	mkdir -p suites/012-numbers/
	python3 make.py

RUNNER_C := /tmp/austral-test-program-runner.c
RUNNER_BIN := austral-test-runner
RUNNER_MODULES := \
	runner/Support.aui,runner/Support.aum \
	runner/Main.aui,runner/Main.aum
RUNNER_DEPS := \
	runner/Support.aui \
	runner/Support.aum \
	runner/Main.aui \
	runner/Main.aum

.PHONY: runner
runner: $(RUNNER_BIN)

$(RUNNER_BIN): $(RUNNER_DEPS) runner_support.c runner_support.h ../austral
	../austral compile $(RUNNER_MODULES) --entrypoint=TestPrograms.Runner.Main:main --target-type=c --output=$(RUNNER_C) --error-format=json
	$(CC) -fwrapv -Wno-builtin-declaration-mismatch -include runner_support.h $(RUNNER_C) runner_support.c -lm -o $(RUNNER_BIN)

clean:
	rm -rf suites/012-numbers/
	rm -f $(RUNNER_BIN) $(RUNNER_C)
