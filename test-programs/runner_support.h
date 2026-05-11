#ifndef AUSTRAL_TEST_RUNNER_SUPPORT_H
#define AUSTRAL_TEST_RUNNER_SUPPORT_H

#include <stdbool.h>
#include <stddef.h>

void* tr_text_from_bytes(const void* data, size_t len);
int tr_text_free(void* text);
bool tr_text_is_null(void* text);
bool tr_text_is_empty(void* text);
bool tr_text_equals(void* left, void* right);
bool tr_text_contains(void* text, void* pattern);
void* tr_text_strip(void* text);
void* tr_text_trim_lines(void* text);
bool tr_bytes_equal(const void* left, size_t left_len, const void* right, size_t right_len);
bool tr_bytes_starts_with(const void* value, size_t value_len, const void* prefix, size_t prefix_len);

void* tr_list_directories(void* path);
size_t tr_dir_list_length(void* list);
void* tr_dir_list_get(void* list, size_t index);
int tr_dir_list_free(void* list);

void* tr_path_join(void* parent, void* child);
void* tr_path_join_bytes(void* parent, const void* child, size_t child_len);
void* tr_temp_path(void* suite, void* test, const void* suffix, size_t suffix_len);
void* tr_read_file_trim(void* path);
void* tr_read_file_raw(void* path);
bool tr_write_file(void* path, void* contents);

void* tr_default_compile_command(void* test_dir, void* c_path);
void* tr_cli_compile_command(void* cli, void* test_dir, void* c_path);
void* tr_c_compiler_command(void* c_path, void* bin_path);
void* tr_binary_command(void* bin_path);

void* tr_run_command(void* command, void* stdin_text);
int tr_command_exit_code(void* result);
void* tr_command_stdout(void* result);
void* tr_command_stderr(void* result);
int tr_command_free(void* result);

int tr_print_result(void* suite, void* test, bool passed);
int tr_reset_failures(void);
int tr_begin_failure_details(
    void* suite,
    void* test,
    void* c_path,
    void* bin_path,
    void* austral_command,
    void* c_command,
    const void* reason,
    size_t reason_len
);
int tr_append_failure_output(const void* label, size_t label_len, void* value);
int tr_end_failure_details(void);

#endif
