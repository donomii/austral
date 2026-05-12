(*
   Part of the Austral project, under the Apache License v2.0 with LLVM Exceptions.
   See LICENSE file for details.

   SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
*)
open CliParser
open Version
open Compiler
open Util
open Error
open HtmlError
open SourceContext
open Project

module Errors = struct
  let project_compile_failed ~name ~stderr =
    austral_raise CliError [
      Text "Project test compilation failed.";
      Break;
      Text "Test: ";
      Code name;
      Break;
      Text "Compiler error:\n";
      Text stderr
    ]

  let project_compile_succeeded_unexpectedly ~name =
    austral_raise CliError [
      Text "Project test compilation succeeded, but failure was expected.";
      Break;
      Text "Test: ";
      Code name
    ]

  let project_compiler_stderr_mismatch ~name ~expected_path ~expected ~actual =
    austral_raise CliError [
      Text "Project test compiler stderr did not match.";
      Break;
      Text "Test: ";
      Code name;
      Break;
      Text "Expected file: ";
      Code expected_path;
      Break;
      Text "Expected:\n";
      Text expected;
      Break;
      Text "Actual:\n";
      Text actual
    ]

  let project_test_failed ~name ~command ~exit_code ~stdout ~stderr =
    austral_raise CliError [
      Text "Project test failed.";
      Break;
      Text "Test: ";
      Code name;
      Break;
      Text "Command: ";
      Code command;
      Break;
      Text "Exit code: ";
      Text (string_of_int exit_code);
      Break;
      Text "Standard output:\n";
      Text stdout;
      Break;
      Text "Standard error:\n";
      Text stderr
    ]

  let project_test_succeeded_unexpectedly ~name ~command ~stdout ~stderr =
    austral_raise CliError [
      Text "Project test program succeeded, but failure was expected.";
      Break;
      Text "Test: ";
      Code name;
      Break;
      Text "Command: ";
      Code command;
      Break;
      Text "Standard output:\n";
      Text stdout;
      Break;
      Text "Standard error:\n";
      Text stderr
    ]

  let project_output_mismatch ~name ~stream ~expected_path ~expected ~actual =
    austral_raise CliError [
      Text "Project test ";
      Text stream;
      Text " did not match.";
      Break;
      Text "Test: ";
      Code name;
      Break;
      Text "Expected file: ";
      Code expected_path;
      Break;
      Text "Expected:\n";
      Text expected;
      Break;
      Text "Actual:\n";
      Text actual
    ]
end

(* Source map stuff *)

(* Map of filenames to file contents. *)
module SourceMap =
  Map.Make(
      struct
        type t = string
        let compare a b = compare a b
      end
    )

type source_map = string SourceMap.t

type compile_outcome =
  | CompileSucceeded
  | CompileFailed of string

(* Parsing file contents *)

let make_module_source (m: mod_source): module_source =
  match m with
  | ModuleSource { inter_path; body_path; } ->
     TwoFileModuleSource {
         int_filename = inter_path;
         int_code = read_file_to_string inter_path;
         body_filename = body_path;
         body_code = read_file_to_string body_path
       }
  | ModuleBodySource { body_path; } ->
     BodyModuleSource {
         body_filename = body_path;
         body_code = read_file_to_string body_path
       }

let parse_source_files (mods: mod_source list): (module_source list * source_map) =
  let contents = List.map make_module_source mods in
  (* Build source map for error handling *)
  let source_maps =
    List.map (fun source ->
        match source with
        | TwoFileModuleSource { int_filename; int_code; body_filename; body_code; } ->
           let smap = SourceMap.empty in
           let smap = SourceMap.add int_filename int_code smap in
           let smap = SourceMap.add body_filename body_code smap in
           smap
        | BodyModuleSource { body_filename; body_code; } ->
           let smap = SourceMap.empty in
           let smap = SourceMap.add body_filename body_code smap in
           smap)
      contents
  in
  let source_map =
    List.fold_left
      (fun sm sm' -> SourceMap.union (fun _ v _ -> Some v) sm sm')
      (SourceMap.empty)
      source_maps
  in
  (contents, source_map)

(* Execution *)

let rec exec (cmd: cmd): unit =
  match cmd with
  | HelpCommand ->
     print_usage ()
  | VersionCommand ->
     print_version ()
  | CompileHelp ->
     print_compile_usage ()
  | BuildHelp ->
     print_build_usage ()
  | TestHelp ->
     print_test_usage ()
  | WholeProgramCompile { modules; target; error_reporting_mode } ->
     exec_compile modules target error_reporting_mode
  | ProjectBuild { options; error_reporting_mode } ->
     exec_project_build options error_reporting_mode
  | ProjectTest { options; error_reporting_mode } ->
     exec_project_test options error_reporting_mode

and print_usage _: unit =
  print_endline ("austral " ^ version_string);
  print_endline "";
  print_endline "Usage:";
  print_endline "    austral [options] <command>";
  print_endline "";
  print_endline "Options:";
  print_endline "    --help     Print this text.";
  print_endline "    --version  Print the compiler's version.";
  print_endline "";
  print_endline "Commands:";
  print_endline "    compile    Compile modules.";
  print_endline "    build      Build a project from austral.json.";
  print_endline "    test       Compile and run project tests from austral.json."

and print_version _: unit =
  print_endline version_string

and print_compile_usage _: unit =
  print_endline "austral compile";
  print_endline "";
  print_endline "Usage:";
  print_endline "    austral compile [options] <module...>";
  print_endline "";
  print_endline "Options:";
  print_endline "    --help          Print this text.";
  print_endline "    --target-type   One of `exe`, `bin`, `tc`, `c`. Default is `exe`.";
  print_endline "    --output        Path to the output file.";
  print_endline "    --entrypoint    The name of the entrypoint function, in the";
  print_endline "                    format `<module name>:<function name>`.";
  print_endline "    --no-entrypoint  Don't compile an entrypoint. Incompatible with";
  print_endline "                    `bin` target.";
  print_endline "";
  print_endline "Positional arguments:";
  print_endline "    module    Of the form 'file.aui,file.aum' for modules with";
  print_endline "              both an interface and body file, or 'file.aum' for";
  print_endline "              modules with only a body."

and print_build_usage _: unit =
  print_endline "austral build";
  print_endline "";
  print_endline "Usage:";
  print_endline "    austral build [options]";
  print_endline "";
  print_endline "Options:";
  print_endline "    --help          Print this text.";
  print_endline "    --project       Path to the project file. Default is austral.json.";
  print_endline "    --target-type   One of `exe`, `bin`, `tc`, `c`.";
  print_endline "    --output        Override the output path.";
  print_endline "    --entrypoint    Override the entrypoint, in the format";
  print_endline "                    `<module name>:<function name>`.";
  print_endline "    --no-entrypoint Compile a C library without an entrypoint.";
  print_endline "    --error-format  One of `plain`, `json`. Default is `plain`."

and print_test_usage _: unit =
  print_endline "austral test";
  print_endline "";
  print_endline "Usage:";
  print_endline "    austral test [options]";
  print_endline "";
  print_endline "Options:";
  print_endline "    --help          Print this text.";
  print_endline "    --project       Path to the project file. Default is austral.json.";
  print_endline "    --name          Compile and run only the named test.";
  print_endline "    --error-format  One of `plain`, `json`. Default is `plain`."

and exec_project_build (options: build_options) (error_reporting_mode: error_reporting_mode): unit =
  let (BuildOptions { project_path; _ }) = options in
  let project = Project.load project_path in
  let (BuildSpec { modules; target }) = Project.build_spec project options in
  exec_compile modules target error_reporting_mode

and exec_project_test (options: test_options) (error_reporting_mode: error_reporting_mode): unit =
  let (TestOptions { project_path; _ }) = options in
  let project = Project.load project_path in
  let specs = Project.test_specs project options in
  List.iter (fun spec -> exec_test_spec spec error_reporting_mode) specs

and exec_test_spec (spec: test_spec) (error_reporting_mode: error_reporting_mode): unit =
  let (TestSpec { test_name; modules; target; expectation; expected_compiler_stderr_path; _ }) = spec in
  Printf.printf "Running %s\n%!" test_name;
  match compile_project_test modules target error_reporting_mode with
  | CompileFailed stderr ->
     (match expectation with
      | ExpectCompileFail ->
         compare_expected_compiler_stderr test_name expected_compiler_stderr_path stderr
      | ExpectPass | ExpectRunFail ->
         Errors.project_compile_failed ~name:test_name ~stderr)
  | CompileSucceeded ->
     (match expectation with
      | ExpectCompileFail ->
         Errors.project_compile_succeeded_unexpectedly ~name:test_name
      | ExpectPass | ExpectRunFail ->
         run_project_test spec)

and run_project_test (spec: test_spec): unit =
  let (TestSpec { test_name; run_binary_path; expectation; expected_stdout_path; expected_stderr_path; stdin_path; _ }) = spec in
  match run_binary_path with
  | None ->
     ()
  | Some path ->
     let stdin =
       match stdin_path with
       | Some path -> read_file_to_string path
       | None -> ""
     in
     let output = run_command_with_stdin (Filename.quote path) stdin in
     let (CommandOutput { command; code; stdout; stderr }) = output in
     compare_expected_output test_name "stdout" expected_stdout_path stdout;
     compare_expected_output test_name "stderr" expected_stderr_path stderr;
     match expectation with
     | ExpectPass ->
        if code <> 0 then
          Errors.project_test_failed ~name:test_name ~command ~exit_code:code ~stdout ~stderr
        else
          ()
     | ExpectRunFail ->
        if code = 0 then
          Errors.project_test_succeeded_unexpectedly ~name:test_name ~command ~stdout ~stderr
        else
          ()
     | ExpectCompileFail ->
        ()

and compare_expected_output (test_name: string) (stream: string) (expected_path: string option) (actual: string): unit =
  match expected_path with
  | Some path ->
     let expected = read_file_to_string path in
     if expected = actual then
       ()
     else
       Errors.project_output_mismatch ~name:test_name ~stream ~expected_path:path ~expected ~actual
  | None ->
     ()

and compare_expected_compiler_stderr (test_name: string) (expected_path: string option) (actual: string): unit =
  match expected_path with
  | Some path ->
     let expected = read_file_to_string path in
     if expected = actual then
       ()
     else
       Errors.project_compiler_stderr_mismatch ~name:test_name ~expected_path:path ~expected ~actual
  | None ->
     ()

and render_compile_error (error: austral_error) (error_reporting_mode: error_reporting_mode) (source_map: source_map): string =
  let error: austral_error = try_adding_source_ctx error source_map in
  match error_reporting_mode with
  | ErrorReportPlain ->
     String.trim (render_error_to_plain error)
  | ErrorReportJson ->
     String.trim (Yojson.Basic.pretty_to_string (render_error_to_json error))

and compile_project_test (modules: mod_source list) (target: target) (error_reporting_mode: error_reporting_mode): compile_outcome =
  let (mods, source_map): (module_source list * source_map) = parse_source_files modules in
  try
    exec_target mods target;
    CompileSucceeded
  with Austral_error error ->
    CompileFailed (render_compile_error error error_reporting_mode source_map)

and exec_compile (modules: mod_source list) (target: target) (error_reporting_mode: error_reporting_mode): unit =
  (* Parse source files *)
  let (mods, source_map): (module_source list * source_map) = parse_source_files modules in
  (* Error handling setup *)
  try
    exec_target mods target
  with Austral_error error ->
    (* Print errors *)
    begin
      match error_reporting_mode with
      | ErrorReportPlain ->
         let error: austral_error = try_adding_source_ctx error source_map in
         Printf.eprintf "%s" (render_error_to_plain error);
         html_error_dump error;
         dump_and_die ()
      | ErrorReportJson ->
         let error: austral_error = try_adding_source_ctx error source_map in
         Printf.eprintf "%s" (Yojson.Basic.pretty_to_string (render_error_to_json error));
         html_error_dump error;
         dump_and_die ()
    end

and dump_and_die _: unit =
  print_endline "Compiler call tree printed to calltree.html";
  Reporter.dump ();
  exit (-1)

and try_adding_source_ctx (error: austral_error) (source_map: source_map): austral_error =
  let (AustralError { span; source_ctx; _ }) = error in
  match source_ctx with
  | Some _ ->
     (* Already have a context. *)
     error
  | None ->
     (match span with
      | Some span ->
         let (Span { filename; _ }) = span in
         (match (SourceMap.find_opt filename source_map) with
          | Some code ->
             add_source_ctx error (get_source_ctx code span)
          | None ->
             error)
      | None ->
         error)

and exec_target (mods: module_source list) (target: target): unit =
  match target with
  | TypeCheck ->
     (* Compile everything, emit no code. *)
     let _ = compile_multiple empty_compiler mods in
     ()
  | Executable { bin_path; entrypoint; } ->
     exec_compile_to_bin mods bin_path entrypoint
  | CStandalone { output_path; entrypoint; } ->
     exec_compile_to_c mods output_path entrypoint

and exec_compile_to_bin (mods: module_source list) (bin_path: string) (entrypoint: entrypoint): unit =
  (* Compile everything to a C file. *)
  let compiler = compile_multiple empty_compiler mods in
  (* Compile the wrapper functions *)
  let compiler = post_compile compiler in
  (* Compile the entrypoint. *)
  let compiler =
    let (Entrypoint (module_name, name)) = entrypoint in
    compile_entrypoint compiler module_name name
  in
  (* Write the output to a temporary file. *)
  let cfile: string = Filename.temp_file "austral_" ".c" in
  write_string_to_file cfile (compiler_code compiler);
  (* Invoke `cc`. *)
  let _ = compile_c_code cfile bin_path in
  ()

and exec_compile_to_c (mods: module_source list) (output_path: string) (entrypoint: entrypoint option): unit =
  (* Compile everything to a C file. *)
  let compiler = compile_multiple empty_compiler mods in
  (* Compile the wrapper functions *)
  let compiler = post_compile compiler in
  (* Compile the entrypoint, if needed. *)
  let compiler =
    match entrypoint with
    | Some (Entrypoint (module_name, name)) ->
       (* It's an executable. *)
       compile_entrypoint compiler module_name name
    | None ->
       (* It's a library. *)
       compiler
  in
  (* Write the output to the given file. *)
  ensure_parent_directory output_path;
  write_string_to_file output_path (compiler_code compiler)
