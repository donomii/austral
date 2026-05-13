#!/usr/bin/env sh
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
AUSTRAL=${AUSTRAL:-"$ROOT/austral"}
CC=${AUSTRAL_CC:-cc}
CFLAGS=${AUSTRAL_CFLAGS:-"-fwrapv"}
LDFLAGS=${AUSTRAL_LDFLAGS:-"-lm"}
TMPROOT=${TMPDIR:-/tmp}

passed=0
failed=0

for case_dir in "$SCRIPT_DIR"/cases/*; do
    case_name=$(basename "$case_dir")
    c_path="$TMPROOT/austral-region-probe-$case_name.c"
    bin_path="$TMPROOT/austral-region-probe-$case_name"
    stdout_path="$TMPROOT/austral-region-probe-$case_name.stdout"
    stderr_path="$TMPROOT/austral-region-probe-$case_name.stderr"
    extra_modules=""

    if [ -f "$case_dir/modules.txt" ]; then
        extra_modules=$(tr '\n' ' ' < "$case_dir/modules.txt")
    fi

    printf '%s ... ' "$case_name"

    if ! "$AUSTRAL" compile $extra_modules "$case_dir/Test.aum" --entrypoint=Test:main --target-type=c --output="$c_path" --error-format=json >"$stdout_path" 2>"$stderr_path"; then
        printf 'FAIL austral-compile\n'
        sed 's/^/    /' "$stderr_path"
        printf '\n'
        failed=$((failed + 1))
        continue
    fi

    if ! "$CC" $CFLAGS "$c_path" $LDFLAGS -o "$bin_path" >"$stdout_path" 2>"$stderr_path"; then
        printf 'FAIL c-compile\n'
        sed 's/^/    /' "$stderr_path"
        printf '\n'
        failed=$((failed + 1))
        continue
    fi

    if ! "$bin_path" >"$stdout_path" 2>"$stderr_path"; then
        printf 'FAIL run\n'
        sed 's/^/    /' "$stderr_path"
        printf '\n'
        failed=$((failed + 1))
        continue
    fi

    printf 'PASS\n'
    passed=$((passed + 1))
done

printf '\nPassed: %s\nFailed: %s\n' "$passed" "$failed"

if [ "$failed" -ne 0 ]; then
    exit 1
fi
