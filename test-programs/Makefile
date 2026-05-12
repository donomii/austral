.PHONY: all
all:
	mkdir -p suites/012-numbers/
	python3 make.py

RUNNER_C := /tmp/austral-test-program-runner.c
RUNNER_BIN := austral-test-runner
STANDARD_MODULES := \
	../standard/src/Buffer.aui,../standard/src/Buffer.aum \
	../standard/src/String.aui,../standard/src/String.aum \
	../standard/src/StringBuilder.aui,../standard/src/StringBuilder.aum \
	../standard/src/OS/Text.aui,../standard/src/OS/Text.aum \
	../standard/src/OS/Environment.aui,../standard/src/OS/Environment.aum \
	../standard/src/OS/FileSystem.aui,../standard/src/OS/FileSystem.aum \
	../standard/src/OS/Process.aui,../standard/src/OS/Process.aum
RUNNER_MODULES := \
	$(STANDARD_MODULES) \
	runner/Support.aui,runner/Support.aum \
	runner/Main.aui,runner/Main.aum
RUNNER_DEPS := \
	../standard/src/Buffer.aui \
	../standard/src/Buffer.aum \
	../standard/src/String.aui \
	../standard/src/String.aum \
	../standard/src/StringBuilder.aui \
	../standard/src/StringBuilder.aum \
	../standard/src/OS/Text.aui \
	../standard/src/OS/Text.aum \
	../standard/src/OS/Environment.aui \
	../standard/src/OS/Environment.aum \
	../standard/src/OS/FileSystem.aui \
	../standard/src/OS/FileSystem.aum \
	../standard/src/OS/Process.aui \
	../standard/src/OS/Process.aum \
	runner/Support.aui \
	runner/Support.aum \
	runner/Main.aui \
	runner/Main.aum

.PHONY: runner
runner: $(RUNNER_BIN)

.PHONY: test
test: $(RUNNER_BIN)
	cd .. && test-programs/$(RUNNER_BIN)

$(RUNNER_BIN): $(RUNNER_DEPS) ../austral
	../austral compile $(RUNNER_MODULES) --entrypoint=TestPrograms.Runner.Main:main --target-type=c --output=$(RUNNER_C) --error-format=json
	$(CC) -fwrapv $(RUNNER_C) -lm -o $(RUNNER_BIN)

clean:
	rm -rf suites/012-numbers/
	rm -f $(RUNNER_BIN) $(RUNNER_C)
