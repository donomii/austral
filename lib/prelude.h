/*
    Part of the Austral project, under the Apache License v2.0 with LLVM Exceptions.
    See LICENSE file for details.

    SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
*/
/* --- BEGIN prelude.h --- */
#include <stdint.h>
#include <stddef.h>

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

extern au_span_t au_make_span(void* data, size_t size);

extern au_span_t au_make_span_from_string(const char* data, size_t size);

extern void* au_array_index(au_span_t* array, size_t index, size_t elem_size);

extern void* au_stdout();

extern void* au_stderr();

extern void* au_stdin();

extern au_unit_t au_abort(au_span_t message);

extern au_unit_t au_printf(const char* format, ...);

extern int au_os_fputc(int c, void* stream);

extern int au_os_fgetc(void* stream);

/*
 * Memory functions
 */

extern void* au_calloc(size_t size, size_t count);

extern void* au_realloc(void* ptr, size_t count);

extern void* au_memmove(void* destination, void* source, size_t count);

extern void* au_memcpy(void* destination, void* source, size_t count);

extern au_unit_t au_free(void* ptr);

/*
 * CLI functions
 */

void au_store_cli_args(int argc, char** argv);

size_t au_get_argc();

au_span_t au_get_nth_arg(size_t n);

/*
 * Small OS support functions used by the standard library.
 *
 * These functions allocate owned C strings with malloc-compatible storage.
 * Callers must release returned strings with au_os_text_free.
 */

char* au_os_text_from_bytes(const au_nat8_t* data, size_t size);

void au_os_text_free(char* text);

size_t au_os_text_length(const char* text);

au_nat8_t au_os_text_byte(const char* text, size_t index);

typedef struct au_os_dir_list au_os_dir_list_t;

au_os_dir_list_t* au_os_list_directories(const char* path);

size_t au_os_dir_list_count(au_os_dir_list_t* list);

char* au_os_dir_list_get(au_os_dir_list_t* list, size_t index);

void au_os_dir_list_free(au_os_dir_list_t* list);

char* au_os_path_join(const char* parent, const char* child);

char* au_os_read_file(const char* path);

au_bool_t au_os_write_file(const char* path, const char* contents);

au_bool_t au_os_append_file(const char* path, const char* contents);

char* au_os_getenv(const char* name);

typedef struct au_os_command_result au_os_command_result_t;

au_os_command_result_t* au_os_run_command(const char* command, const char* stdin_text);

int au_os_command_exit_code(au_os_command_result_t* result);

char* au_os_command_stdout(au_os_command_result_t* result);

char* au_os_command_stderr(au_os_command_result_t* result);

void au_os_command_result_free(au_os_command_result_t* result);

/* --- END prelude.h --- */
