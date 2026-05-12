/*
    Part of the Austral project, under the Apache License v2.0 with LLVM Exceptions.
    See LICENSE file for details.

    SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
*/
#include <stdint.h>
#include <stddef.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/wait.h>
#include <unistd.h>

/*
 * Austral types
 */

typedef uint8_t   au_unit_t;
typedef uint8_t   au_bool_t;
typedef uint8_t   au_nat8_t;
typedef int8_t    au_int8_t;
typedef uint16_t  au_nat16_t;
typedef int16_t   au_int16_t;
typedef uint32_t  au_nat32_t;
typedef int32_t   au_int32_t;
typedef uint64_t  au_nat64_t;
typedef int64_t   au_int64_t;
typedef size_t    au_index_t;
typedef void*     au_fnptr_t;
typedef uint8_t   au_region_t;

#define nil   0
#define false 0
#define true  1

/*
 * A little hack
 */

#define AU_STORE(ptr, val) (*(ptr) = (val), nil)

/*
 * Pervasive
 */

typedef struct {
  void* data;
  size_t size;
} au_span_t;

au_span_t au_make_span(void* data, size_t size) {
  return (au_span_t){ .data = data, .size = size };
}

au_span_t au_make_span_from_string(const char* data, size_t size) {
  return (au_span_t){ .data = (void*) data, .size = size };
}

void* au_stdout() {
  return (void*) stdout;
}

void* au_stderr() {
  return (void*) stderr;
}

void* au_stdin() {
  return (void*) stdin;
}

au_unit_t au_abort_internal(const char* message) {
  FILE* stderr_stream = (FILE*) au_stderr();

  fprintf(stderr_stream, "%s\n", message);
  fflush(stderr_stream);
  _Exit(-1);

  return nil;
}

au_unit_t au_abort(au_span_t message) {
  FILE* stderr_stream = (FILE*) au_stderr();

  fprintf(stderr_stream, "%s\n", (char*) message.data);
  fflush(stderr_stream);
  _Exit(-1);
  return nil;
}

au_unit_t au_printf(const char* format, ...) {
  va_list args;
  va_start(args, format);
  vprintf(format, args);
  va_end(args);
  return nil;
}

int au_os_fputc(int c, void* stream) {
  return fputc(c, (FILE*) stream);
}

int au_os_fgetc(void* stream) {
  return fgetc((FILE*) stream);
}

void* au_array_index(au_span_t* array, size_t index, size_t elem_size) {
  if (index >= array->size) {
    au_abort_internal("Array index out of bounds.");
  }

  au_index_t offset = 0;
  if (__builtin_mul_overflow(index, elem_size, &offset)) {
    au_abort_internal("Multiplication overflow in array indexing operation.");
  }

  char* data = (char*) array->data;
  char* ptr = data + offset;
  return (void*)(ptr);
}

/*
 * Memory functions
 */

void* au_calloc(size_t size, size_t count) {
  return calloc(size, count);
}

void* au_realloc(void* ptr, size_t count) {
  return realloc(ptr, count);
}

void* au_memmove(void* destination, void* source, size_t count) {
  return memmove(destination, source, count);
}

void* au_memcpy(void* destination, void* source, size_t count) {
  return memcpy(destination, source, count);
}

au_unit_t au_free(void* ptr) {
  free(ptr);
  return nil;
};

/*
 * CLI functions
 */

static int _au_argc = -1;

static char** _au_argv = NULL;

void au_store_cli_args(int argc, char** argv) {
  // Sanity checks.
  if (argc < 0) {
    au_abort_internal("Entrypoint error: argc is negative.");
  }
  if (argv == NULL) {
    au_abort_internal("Entrypoint error: argv is NULL.");
  }
  // Store values.
  _au_argc = argc;
  _au_argv = argv;
}

size_t au_get_argc() {
  // Sanity check.
  if (_au_argc == -1) {
    au_abort_internal("Prelude error: argc was not set.");
  }
  // Correctness argument: if _au_argc is non-negative, being an `int`, it
  // should fit inside `size_t`.
  size_t argc = (size_t)(_au_argc);
  return argc;
}

size_t _au_bounded_strlen(char* string, size_t bound) {
  size_t size = 0;
  for(size_t idx = 0; idx <= bound; idx++) {
    if (string[idx] == '\0') {
      return size;
    }
    size++;
  }
  au_abort_internal("Command line argument exceeds maximum length of 10 kibibytes.");
  return 0;
}

/* One kibibyte in bytes. */
#define AU_KIBIBYTE 1024
/* The maximum size of each CLI arg. */
#define AU_MAX_ARG_SIZE (10*AU_KIBIBYTE)

au_span_t au_get_nth_arg(size_t n) {
  // Sanity check.
  if (_au_argv == NULL) {
    au_abort_internal("Prelude error: argv was not set.");
  }
  size_t argc = au_get_argc();
  // Check array bounds.
  if (n >= argc) {
    au_abort_internal("Command line argument access out of bounds.");
  }
  // Retrieve the nth argument.
  char* arg = _au_argv[n];
  // Check non-null.
  if (arg == NULL) {
    au_abort_internal("Prelude error: command-line argument is NULL.");
  }
  // Measure the length.
  size_t size = _au_bounded_strlen(arg, AU_MAX_ARG_SIZE);
  // Otherwise, return it.
  au_span_t arg_array = ((au_span_t){ .data = (void*)arg, .size = size });
  return arg_array;
}

/*
 * Small OS support functions.
 */

char* au_os_text_from_bytes(const au_nat8_t* data, size_t size) {
  char* result = (char*) malloc(size + 1);
  if (result == NULL) {
    au_abort_internal("au_os_text_from_bytes: allocation failed.");
  }
  if (size > 0 && data != NULL) {
    memcpy(result, data, size);
  }
  result[size] = '\0';
  return result;
}

void au_os_text_free(char* text) {
  free(text);
}

size_t au_os_text_length(const char* text) {
  if (text == NULL) {
    return 0;
  }
  return strlen(text);
}

au_nat8_t au_os_text_byte(const char* text, size_t index) {
  if (text == NULL) {
    au_abort_internal("au_os_text_byte: null text.");
  }
  return (au_nat8_t) text[index];
}

static char* au_os_strdup(const char* text) {
  if (text == NULL) {
    text = "";
  }
  return au_os_text_from_bytes((const au_nat8_t*) text, strlen(text));
}

typedef struct au_os_dir_list au_os_dir_list_t;

struct au_os_dir_list {
  size_t count;
  char** names;
};

static int au_os_string_ptr_cmp(const void* left, const void* right) {
  const char* const* a = (const char* const*) left;
  const char* const* b = (const char* const*) right;
  return strcmp(*a, *b);
}

char* au_os_path_join(const char* parent, const char* child) {
  if (parent == NULL) {
    parent = "";
  }
  if (child == NULL) {
    child = "";
  }
  size_t parent_len = strlen(parent);
  size_t child_len = strlen(child);
  size_t needs_slash = parent_len > 0 && parent[parent_len - 1] != '/';
  size_t total = parent_len + needs_slash + child_len;
  char* result = (char*) malloc(total + 1);
  if (result == NULL) {
    au_abort_internal("au_os_path_join: allocation failed.");
  }
  memcpy(result, parent, parent_len);
  size_t pos = parent_len;
  if (needs_slash) {
    result[pos] = '/';
    pos++;
  }
  memcpy(result + pos, child, child_len);
  result[total] = '\0';
  return result;
}

au_os_dir_list_t* au_os_list_directories(const char* path) {
  au_os_dir_list_t* list = (au_os_dir_list_t*) calloc(1, sizeof(au_os_dir_list_t));
  if (list == NULL) {
    au_abort_internal("au_os_list_directories: allocation failed.");
  }
  if (path == NULL) {
    return list;
  }
  DIR* dir = opendir(path);
  if (dir == NULL) {
    return list;
  }
  struct dirent* entry = NULL;
  while ((entry = readdir(dir)) != NULL) {
    if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
      continue;
    }
    char* child_path = au_os_path_join(path, entry->d_name);
    DIR* child_dir = opendir(child_path);
    free(child_path);
    if (child_dir == NULL) {
      continue;
    }
    closedir(child_dir);
    char** names = (char**) realloc(list->names, sizeof(char*) * (list->count + 1));
    if (names == NULL) {
      au_abort_internal("au_os_list_directories: allocation failed.");
    }
    list->names = names;
    list->names[list->count] = au_os_strdup(entry->d_name);
    list->count++;
  }
  closedir(dir);
  qsort(list->names, list->count, sizeof(char*), au_os_string_ptr_cmp);
  return list;
}

size_t au_os_dir_list_count(au_os_dir_list_t* list) {
  if (list == NULL) {
    return 0;
  }
  return list->count;
}

char* au_os_dir_list_get(au_os_dir_list_t* list, size_t index) {
  if (list == NULL || index >= list->count) {
    return au_os_strdup("");
  }
  return au_os_strdup(list->names[index]);
}

void au_os_dir_list_free(au_os_dir_list_t* list) {
  if (list != NULL) {
    for (size_t i = 0; i < list->count; i++) {
      free(list->names[i]);
    }
    free(list->names);
    free(list);
  }
}

char* au_os_read_file(const char* path) {
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
    fclose(file);
    au_abort_internal("au_os_read_file: allocation failed.");
  }
  size_t read_count = fread(data, 1, (size_t) size, file);
  data[read_count] = '\0';
  fclose(file);
  return data;
}

au_bool_t au_os_write_file(const char* path, const char* contents) {
  FILE* file = fopen(path, "wb");
  if (file == NULL) {
    return false;
  }
  if (contents == NULL) {
    contents = "";
  }
  size_t size = strlen(contents);
  au_bool_t ok = fwrite(contents, 1, size, file) == size;
  fclose(file);
  return ok;
}

au_bool_t au_os_append_file(const char* path, const char* contents) {
  FILE* file = fopen(path, "ab");
  if (file == NULL) {
    return false;
  }
  if (contents == NULL) {
    contents = "";
  }
  size_t size = strlen(contents);
  au_bool_t ok = fwrite(contents, 1, size, file) == size;
  fclose(file);
  return ok;
}

char* au_os_getenv(const char* name) {
  char* value = getenv(name);
  if (value == NULL) {
    return NULL;
  }
  return au_os_strdup(value);
}

typedef struct au_os_command_result au_os_command_result_t;

struct au_os_command_result {
  int exit_code;
  char* stdout_data;
  char* stderr_data;
};

static char* au_os_shell_quote(const char* value) {
  if (value == NULL) {
    value = "";
  }
  size_t cap = strlen(value) * 4 + 3;
  char* result = (char*) malloc(cap);
  if (result == NULL) {
    au_abort_internal("au_os_shell_quote: allocation failed.");
  }
  size_t pos = 0;
  result[pos++] = '\'';
  for (const char* cursor = value; *cursor != '\0'; cursor++) {
    if (*cursor == '\'') {
      memcpy(result + pos, "'\\''", 4);
      pos += 4;
    } else {
      result[pos++] = *cursor;
    }
  }
  result[pos++] = '\'';
  result[pos] = '\0';
  return result;
}

static char* au_os_read_temp_file(const char* path) {
  char* contents = au_os_read_file(path);
  if (contents == NULL) {
    return au_os_strdup("");
  }
  return contents;
}

au_os_command_result_t* au_os_run_command(const char* command, const char* stdin_text) {
  char stdout_path[] = "/tmp/austral_process_stdout_XXXXXX";
  char stderr_path[] = "/tmp/austral_process_stderr_XXXXXX";
  char stdin_path[] = "/tmp/austral_process_stdin_XXXXXX";

  int stdout_fd = mkstemp(stdout_path);
  int stderr_fd = mkstemp(stderr_path);
  if (stdout_fd < 0 || stderr_fd < 0) {
    au_abort_internal("au_os_run_command: could not create output files.");
  }
  close(stdout_fd);
  close(stderr_fd);

  au_bool_t has_stdin = stdin_text != NULL;
  if (has_stdin) {
    int stdin_fd = mkstemp(stdin_path);
    if (stdin_fd < 0) {
      au_abort_internal("au_os_run_command: could not create input file.");
    }
    size_t stdin_len = strlen(stdin_text);
    if (stdin_len > 0) {
      ssize_t written = write(stdin_fd, stdin_text, stdin_len);
      if (written < 0) {
        au_abort_internal("au_os_run_command: could not write input file.");
      }
    }
    close(stdin_fd);
  }

  char* quoted_stdout = au_os_shell_quote(stdout_path);
  char* quoted_stderr = au_os_shell_quote(stderr_path);
  char* quoted_stdin = has_stdin ? au_os_shell_quote(stdin_path) : NULL;
  size_t shell_size =
    strlen(command == NULL ? "" : command)
    + strlen(quoted_stdout)
    + strlen(quoted_stderr)
    + (quoted_stdin == NULL ? 0 : strlen(quoted_stdin))
    + 32;
  char* shell_command = (char*) malloc(shell_size);
  if (shell_command == NULL) {
    au_abort_internal("au_os_run_command: allocation failed.");
  }
  if (has_stdin) {
    snprintf(shell_command, shell_size, "( %s ) < %s > %s 2> %s", command, quoted_stdin, quoted_stdout, quoted_stderr);
  } else {
    snprintf(shell_command, shell_size, "( %s ) > %s 2> %s", command, quoted_stdout, quoted_stderr);
  }

  int status = system(shell_command);
  int code = -1;
  if (status != -1 && WIFEXITED(status)) {
    code = WEXITSTATUS(status);
  } else if (status != -1 && WIFSIGNALED(status)) {
    code = 128 + WTERMSIG(status);
  } else if (status != -1) {
    code = status;
  }

  au_os_command_result_t* result =
    (au_os_command_result_t*) calloc(1, sizeof(au_os_command_result_t));
  if (result == NULL) {
    au_abort_internal("au_os_run_command: allocation failed.");
  }
  result->exit_code = code;
  result->stdout_data = au_os_read_temp_file(stdout_path);
  result->stderr_data = au_os_read_temp_file(stderr_path);

  unlink(stdout_path);
  unlink(stderr_path);
  if (has_stdin) {
    unlink(stdin_path);
  }
  free(quoted_stdout);
  free(quoted_stderr);
  free(quoted_stdin);
  free(shell_command);
  return result;
}

int au_os_command_exit_code(au_os_command_result_t* result) {
  if (result == NULL) {
    return -1;
  }
  return result->exit_code;
}

char* au_os_command_stdout(au_os_command_result_t* result) {
  if (result == NULL) {
    return au_os_strdup("");
  }
  return au_os_strdup(result->stdout_data);
}

char* au_os_command_stderr(au_os_command_result_t* result) {
  if (result == NULL) {
    return au_os_strdup("");
  }
  return au_os_strdup(result->stderr_data);
}

void au_os_command_result_free(au_os_command_result_t* result) {
  if (result != NULL) {
    free(result->stdout_data);
    free(result->stderr_data);
    free(result);
  }
}
