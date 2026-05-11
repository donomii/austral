#define _POSIX_C_SOURCE 200809L

#include "runner_support.h"

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

typedef struct {
    char* data;
} TrText;

typedef struct {
    size_t count;
    char** names;
} TrDirList;

typedef struct {
    int exit_code;
    char* stdout_data;
    char* stderr_data;
} TrCommandResult;

static const char* as_cstr(void* text) {
    if (text == NULL) {
        return "";
    }
    return ((TrText*) text)->data;
}

static TrText* text_from_owned(char* data) {
    TrText* text = (TrText*) calloc(1, sizeof(TrText));
    if (text == NULL) {
        abort();
    }
    text->data = data;
    return text;
}

static TrText* text_from_cstr(const char* value) {
    if (value == NULL) {
        value = "";
    }
    char* copy = strdup(value);
    if (copy == NULL) {
        abort();
    }
    return text_from_owned(copy);
}

static char* bytes_to_cstr(const void* data, size_t len) {
    char* result = (char*) malloc(len + 1);
    if (result == NULL) {
        abort();
    }
    if (len > 0) {
        memcpy(result, data, len);
    }
    result[len] = '\0';
    return result;
}

void* tr_text_from_bytes(const void* data, size_t len) {
    return text_from_owned(bytes_to_cstr(data, len));
}

int tr_text_free(void* text) {
    if (text != NULL) {
        TrText* value = (TrText*) text;
        free(value->data);
        free(value);
    }
    return 0;
}

bool tr_text_is_null(void* text) {
    return text == NULL;
}

bool tr_text_is_empty(void* text) {
    return as_cstr(text)[0] == '\0';
}

bool tr_text_equals(void* left, void* right) {
    return strcmp(as_cstr(left), as_cstr(right)) == 0;
}

bool tr_text_contains(void* text, void* pattern) {
    return strstr(as_cstr(text), as_cstr(pattern)) != NULL;
}

static char* strip_copy(const char* value) {
    const unsigned char* start = (const unsigned char*) value;
    while (*start != '\0' && isspace(*start)) {
        start++;
    }
    const unsigned char* end = (const unsigned char*) value + strlen(value);
    while (end > start && isspace(*(end - 1))) {
        end--;
    }
    return bytes_to_cstr(start, (size_t) (end - start));
}

void* tr_text_strip(void* text) {
    return text_from_owned(strip_copy(as_cstr(text)));
}

static bool all_space(const char* start, const char* end) {
    for (const char* p = start; p < end; p++) {
        if (!isspace((unsigned char) *p)) {
            return false;
        }
    }
    return true;
}

void* tr_text_trim_lines(void* text) {
    char* stripped = strip_copy(as_cstr(text));
    size_t cap = strlen(stripped) + 1;
    char* out = (char*) calloc(cap, 1);
    if (out == NULL) {
        abort();
    }
    size_t out_len = 0;
    char* line = stripped;
    bool first = true;
    while (line != NULL) {
        char* newline = strchr(line, '\n');
        char* line_end = newline == NULL ? line + strlen(line) : newline;
        if (!first) {
            out[out_len++] = '\n';
        }
        if (!all_space(line, line_end)) {
            size_t line_len = (size_t) (line_end - line);
            memcpy(out + out_len, line, line_len);
            out_len += line_len;
        }
        first = false;
        if (newline == NULL) {
            break;
        }
        line = newline + 1;
    }
    out[out_len] = '\0';
    free(stripped);
    return text_from_owned(out);
}

bool tr_bytes_equal(const void* left, size_t left_len, const void* right, size_t right_len) {
    if (left_len != right_len) {
        return false;
    }
    return memcmp(left, right, left_len) == 0;
}

bool tr_bytes_starts_with(const void* value, size_t value_len, const void* prefix, size_t prefix_len) {
    if (value_len < prefix_len) {
        return false;
    }
    return memcmp(value, prefix, prefix_len) == 0;
}

static int cmp_string_ptr(const void* left, const void* right) {
    const char* const* a = (const char* const*) left;
    const char* const* b = (const char* const*) right;
    return strcmp(*a, *b);
}

static char* join_path_cstr(const char* parent, const char* child) {
    size_t parent_len = strlen(parent);
    size_t child_len = strlen(child);
    bool needs_slash = parent_len > 0 && parent[parent_len - 1] != '/';
    size_t total = parent_len + (needs_slash ? 1 : 0) + child_len;
    char* result = (char*) malloc(total + 1);
    if (result == NULL) {
        abort();
    }
    memcpy(result, parent, parent_len);
    size_t pos = parent_len;
    if (needs_slash) {
        result[pos++] = '/';
    }
    memcpy(result + pos, child, child_len);
    result[total] = '\0';
    return result;
}

void* tr_list_directories(void* path_text) {
    const char* path = as_cstr(path_text);
    DIR* dir = opendir(path);
    TrDirList* list = (TrDirList*) calloc(1, sizeof(TrDirList));
    if (list == NULL) {
        abort();
    }
    if (dir == NULL) {
        return list;
    }

    struct dirent* entry = NULL;
    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        char* child_path = join_path_cstr(path, entry->d_name);
        struct stat st;
        int stat_result = stat(child_path, &st);
        free(child_path);
        if (stat_result != 0 || !S_ISDIR(st.st_mode)) {
            continue;
        }
        char** names = (char**) realloc(list->names, sizeof(char*) * (list->count + 1));
        if (names == NULL) {
            abort();
        }
        list->names = names;
        list->names[list->count] = strdup(entry->d_name);
        if (list->names[list->count] == NULL) {
            abort();
        }
        list->count++;
    }
    closedir(dir);
    qsort(list->names, list->count, sizeof(char*), cmp_string_ptr);
    return list;
}

size_t tr_dir_list_length(void* list) {
    if (list == NULL) {
        return 0;
    }
    return ((TrDirList*) list)->count;
}

void* tr_dir_list_get(void* list, size_t index) {
    TrDirList* dirs = (TrDirList*) list;
    if (dirs == NULL || index >= dirs->count) {
        return text_from_cstr("");
    }
    return text_from_cstr(dirs->names[index]);
}

int tr_dir_list_free(void* list) {
    if (list != NULL) {
        TrDirList* dirs = (TrDirList*) list;
        for (size_t i = 0; i < dirs->count; i++) {
            free(dirs->names[i]);
        }
        free(dirs->names);
        free(dirs);
    }
    return 0;
}

void* tr_path_join(void* parent, void* child) {
    return text_from_owned(join_path_cstr(as_cstr(parent), as_cstr(child)));
}

void* tr_path_join_bytes(void* parent, const void* child, size_t child_len) {
    char* child_copy = bytes_to_cstr(child, child_len);
    char* joined = join_path_cstr(as_cstr(parent), child_copy);
    free(child_copy);
    return text_from_owned(joined);
}

void* tr_temp_path(void* suite, void* test, const void* suffix, size_t suffix_len) {
    char* suffix_copy = bytes_to_cstr(suffix, suffix_len);
    const char* suite_name = as_cstr(suite);
    const char* test_name = as_cstr(test);
    size_t len = strlen("/tmp/austral_e2e_") + strlen(suite_name) + 1 + strlen(test_name) + strlen(suffix_copy);
    char* result = (char*) malloc(len + 1);
    if (result == NULL) {
        abort();
    }
    snprintf(result, len + 1, "/tmp/austral_e2e_%s_%s%s", suite_name, test_name, suffix_copy);
    free(suffix_copy);
    return text_from_owned(result);
}

static char* read_file_or_null(const char* path) {
    FILE* file = fopen(path, "rb");
    if (file == NULL) {
        return NULL;
    }
    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return NULL;
    }
    long size = ftell(file);
    if (size < 0) {
        fclose(file);
        return NULL;
    }
    rewind(file);
    char* data = (char*) malloc((size_t) size + 1);
    if (data == NULL) {
        abort();
    }
    size_t read = fread(data, 1, (size_t) size, file);
    data[read] = '\0';
    fclose(file);
    return data;
}

void* tr_read_file_trim(void* path) {
    char* raw = read_file_or_null(as_cstr(path));
    if (raw == NULL) {
        return NULL;
    }
    char* stripped = strip_copy(raw);
    free(raw);
    return text_from_owned(stripped);
}

void* tr_read_file_raw(void* path) {
    char* raw = read_file_or_null(as_cstr(path));
    if (raw == NULL) {
        return NULL;
    }
    return text_from_owned(raw);
}

bool tr_write_file(void* path, void* contents) {
    FILE* file = fopen(as_cstr(path), "wb");
    if (file == NULL) {
        return false;
    }
    const char* data = as_cstr(contents);
    size_t len = strlen(data);
    bool ok = fwrite(data, 1, len, file) == len;
    fclose(file);
    return ok;
}

static char* appendf(char* base, const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    va_list copy;
    va_copy(copy, args);
    int needed = vsnprintf(NULL, 0, fmt, copy);
    va_end(copy);
    if (needed < 0) {
        abort();
    }
    size_t base_len = base == NULL ? 0 : strlen(base);
    char* result = (char*) realloc(base, base_len + (size_t) needed + 1);
    if (result == NULL) {
        abort();
    }
    vsnprintf(result + base_len, (size_t) needed + 1, fmt, args);
    va_end(args);
    return result;
}

static char* shell_quote(const char* value) {
    char* out = strdup("'");
    if (out == NULL) {
        abort();
    }
    for (const char* p = value; *p != '\0'; p++) {
        if (*p == '\'') {
            out = appendf(out, "'\\''");
        } else {
            char buf[2] = {*p, '\0'};
            out = appendf(out, "%s", buf);
        }
    }
    out = appendf(out, "'");
    return out;
}

static char* replace_all(const char* input, const char* needle, const char* replacement) {
    size_t needle_len = strlen(needle);
    if (needle_len == 0) {
        return strdup(input);
    }
    char* out = strdup("");
    if (out == NULL) {
        abort();
    }
    const char* cur = input;
    const char* match = NULL;
    while ((match = strstr(cur, needle)) != NULL) {
        out = appendf(out, "%.*s%s", (int) (match - cur), cur, replacement);
        cur = match + needle_len;
    }
    out = appendf(out, "%s", cur);
    return out;
}

void* tr_default_compile_command(void* test_dir, void* c_path) {
    char* body = join_path_cstr(as_cstr(test_dir), "Test.aum");
    char* quoted_body = shell_quote(body);
    char* quoted_c = shell_quote(as_cstr(c_path));
    char* command = NULL;
    command = appendf(command, "./austral compile %s --entrypoint=Test:main --target-type=c --output=%s --error-format=json", quoted_body, quoted_c);
    free(body);
    free(quoted_body);
    free(quoted_c);
    return text_from_owned(command);
}

void* tr_cli_compile_command(void* cli, void* test_dir, void* c_path) {
    char* step_one = replace_all(as_cstr(cli), "$DIR", as_cstr(test_dir));
    char* step_two = replace_all(step_one, "$C_PATH", as_cstr(c_path));
    free(step_one);
    return text_from_owned(step_two);
}

void* tr_c_compiler_command(void* c_path, void* bin_path) {
    const char* cc = getenv("AUSTRAL_CC");
    if (cc == NULL || cc[0] == '\0') {
        cc = "gcc";
    }
    const char* cflags = getenv("AUSTRAL_CFLAGS");
    if (cflags == NULL) {
        cflags = "";
    }
    const char* ldflags = getenv("AUSTRAL_LDFLAGS");
    if (ldflags == NULL) {
        ldflags = "";
    }
    char* quoted_c = shell_quote(as_cstr(c_path));
    char* quoted_bin = shell_quote(as_cstr(bin_path));
    char* command = NULL;
    command = appendf(command, "%s -fwrapv -Wno-builtin-declaration-mismatch", cc);
    if (cflags[0] != '\0') {
        command = appendf(command, " %s", cflags);
    }
    command = appendf(command, " %s -lm", quoted_c);
    if (ldflags[0] != '\0') {
        command = appendf(command, " %s", ldflags);
    }
    command = appendf(command, " -o %s", quoted_bin);
    free(quoted_c);
    free(quoted_bin);
    return text_from_owned(command);
}

void* tr_binary_command(void* bin_path) {
    char* quoted_bin = shell_quote(as_cstr(bin_path));
    return text_from_owned(quoted_bin);
}

static char* read_whole_temp(const char* path) {
    char* data = read_file_or_null(path);
    if (data == NULL) {
        return strdup("");
    }
    return data;
}

void* tr_run_command(void* command_text, void* stdin_text) {
    char stdout_path[] = "/tmp/austral_runner_stdout_XXXXXX";
    char stderr_path[] = "/tmp/austral_runner_stderr_XXXXXX";
    char stdin_path[] = "/tmp/austral_runner_stdin_XXXXXX";
    int stdout_fd = mkstemp(stdout_path);
    int stderr_fd = mkstemp(stderr_path);
    if (stdout_fd < 0 || stderr_fd < 0) {
        abort();
    }
    close(stdout_fd);
    close(stderr_fd);

    bool has_stdin = stdin_text != NULL;
    int stdin_fd = -1;
    if (has_stdin) {
        stdin_fd = mkstemp(stdin_path);
        if (stdin_fd < 0) {
            abort();
        }
        const char* input = as_cstr(stdin_text);
        size_t len = strlen(input);
        if (len > 0) {
            ssize_t written = write(stdin_fd, input, len);
            if (written < 0) {
                abort();
            }
        }
        close(stdin_fd);
    }

    char* q_stdout = shell_quote(stdout_path);
    char* q_stderr = shell_quote(stderr_path);
    char* shell = NULL;
    if (has_stdin) {
        char* q_stdin = shell_quote(stdin_path);
        shell = appendf(shell, "( %s ) < %s > %s 2> %s", as_cstr(command_text), q_stdin, q_stdout, q_stderr);
        free(q_stdin);
    } else {
        shell = appendf(shell, "( %s ) > %s 2> %s", as_cstr(command_text), q_stdout, q_stderr);
    }

    int status = system(shell);
    int code = -1;
    if (status != -1 && WIFEXITED(status)) {
        code = WEXITSTATUS(status);
    } else if (status != -1 && WIFSIGNALED(status)) {
        code = 128 + WTERMSIG(status);
    }

    TrCommandResult* result = (TrCommandResult*) calloc(1, sizeof(TrCommandResult));
    if (result == NULL) {
        abort();
    }
    result->exit_code = code;
    result->stdout_data = read_whole_temp(stdout_path);
    result->stderr_data = read_whole_temp(stderr_path);

    unlink(stdout_path);
    unlink(stderr_path);
    if (has_stdin) {
        unlink(stdin_path);
    }
    free(shell);
    free(q_stdout);
    free(q_stderr);
    return result;
}

int tr_command_exit_code(void* result) {
    if (result == NULL) {
        return -1;
    }
    return ((TrCommandResult*) result)->exit_code;
}

void* tr_command_stdout(void* result) {
    if (result == NULL) {
        return text_from_cstr("");
    }
    return text_from_cstr(((TrCommandResult*) result)->stdout_data);
}

void* tr_command_stderr(void* result) {
    if (result == NULL) {
        return text_from_cstr("");
    }
    return text_from_cstr(((TrCommandResult*) result)->stderr_data);
}

int tr_command_free(void* result) {
    if (result != NULL) {
        TrCommandResult* command = (TrCommandResult*) result;
        free(command->stdout_data);
        free(command->stderr_data);
        free(command);
    }
    return 0;
}

int tr_print_result(void* suite, void* test, bool passed) {
    printf("%-45s  %-45s  %s\n", as_cstr(suite), as_cstr(test), passed ? "PASS" : "FAIL");
    fflush(stdout);
    return 0;
}

int tr_reset_failures(void) {
    FILE* file = fopen("FAILURES.txt", "wb");
    if (file != NULL) {
        fclose(file);
    }
    return 0;
}

static void write_span(FILE* file, const void* data, size_t len) {
    if (len > 0) {
        fwrite(data, 1, len, file);
    }
}

static void write_output(FILE* file, const void* label, size_t label_len, void* value) {
    if (label_len == 0) {
        return;
    }
    write_span(file, label, label_len);
    fprintf(file, "\n");
    const char* data = as_cstr(value);
    const char* line = data;
    while (line != NULL) {
        const char* newline = strchr(line, '\n');
        if (newline == NULL) {
            fprintf(file, "\t%s\n", line);
            break;
        } else {
            fprintf(file, "\t%.*s\n", (int) (newline - line), line);
            line = newline + 1;
        }
    }
    fprintf(file, "\n");
}

int tr_begin_failure_details(
    void* suite,
    void* test,
    void* c_path,
    void* bin_path,
    void* austral_command,
    void* c_command,
    const void* reason,
    size_t reason_len
) {
    FILE* file = fopen("FAILURES.txt", "ab");
    if (file == NULL) {
        return -1;
    }
    fprintf(file, "Suite: %s\n", as_cstr(suite));
    fprintf(file, "Test: %s\n", as_cstr(test));
    fprintf(file, "C File: %s\n", as_cstr(c_path));
    fprintf(file, "Bin File: %s\n", as_cstr(bin_path));
    fprintf(file, "Austral command: %s\n", as_cstr(austral_command));
    fprintf(file, "C compiler command: %s\n", as_cstr(c_command));
    fprintf(file, "Reason: ");
    write_span(file, reason, reason_len);
    fprintf(file, "\n");
    fclose(file);
    return 0;
}

int tr_append_failure_output(const void* label, size_t label_len, void* value) {
    FILE* file = fopen("FAILURES.txt", "ab");
    if (file == NULL) {
        return -1;
    }
    write_output(file, label, label_len, value);
    fclose(file);
    return 0;
}

int tr_end_failure_details(void) {
    FILE* file = fopen("FAILURES.txt", "ab");
    if (file == NULL) {
        return -1;
    }
    fprintf(file, "\n\n\n\n\n");
    fclose(file);
    return 0;
}
