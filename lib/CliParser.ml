(*
   Part of the Austral project, under the Apache License v2.0 with LLVM Exceptions.
   See LICENSE file for details.

   SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
*)
open Identifier
open CliUtil
open Error

module Errors = struct
  let invalid_entrypoint entry =
    austral_raise CliError [
      Text "Invalid entrypoint format ";
      Code entry;
      Break;
      Text "The entrypoint must be supplied in the form ";
      Code "Module:name"
    ]

  let invalid_module_source source =
    austral_raise CliError [
      Text "Invalid module source format ";
      Code source;
      Break;
      Text "Sources must be supplied as either";
      Code "interface.aui,body.aum";
      Text " or ";
      Code "body.aum"
    ]

  let missing_entrypoint () =
    austral_raise CliError [
      Code "--entrypoint";
      Text " argument not provided."
    ]

  let missing_module () =
    austral_raise CliError [
      Text "The ";
      Code "compile";
      Text " command must specify at least one module."
    ]

  let missing_test_name () =
    austral_raise CliError [
      Code "--name";
      Text " requires a test name."
    ]

  let missing_output () =
    austral_raise CliError [
      Code "--output";
      Text " argument not provided."
    ]

  let no_entrypoint_wrong_target () =
    austral_raise CliError [
      Code "--no-entrypoint";
      Text " requires ";
      Code "--target-type=c";
      Text ", because otherwise the compiler will try to build the generated C code, and will fail because there is no entrypoint function."
    ]

  let unknown_target target =
    austral_raise CliError [
      Text "Unknown target type ";
      Code target
    ]

  let unknown_error_reporting_mode (mode: string) =
    austral_raise CliError [
      Text "Unknown error reporting mode: ";
      Code mode;
      Text ". Valid values are ";
      Code "plain";
      Text " and ";
      Code "json";
      Text "."
    ]
end

type entrypoint =
  | Entrypoint of module_name * identifier
[@@deriving eq]

type mod_source =
  | ModuleSource of { inter_path: string; body_path: string }
  | ModuleBodySource of { body_path: string }
[@@deriving eq]

type target =
  | TypeCheck
  | Executable of { bin_path: string; entrypoint: entrypoint; }
  | CStandalone of { output_path: string; entrypoint: entrypoint option; }
[@@deriving eq]

type error_reporting_mode =
  | ErrorReportPlain
  | ErrorReportJson
[@@deriving eq]

type build_options =
  BuildOptions of {
      project_path: string;
      target_type: string option;
      output_path: string option;
      entrypoint: entrypoint option;
      no_entrypoint: bool;
    }
[@@deriving eq]

type test_options =
  TestOptions of {
      project_path: string;
      test_name: string option;
    }
[@@deriving eq]

type cmd =
  | HelpCommand
  | VersionCommand
  | CompileHelp
  | BuildHelp
  | TestHelp
  | WholeProgramCompile of {
      modules: mod_source list;
      target: target;
      error_reporting_mode: error_reporting_mode;
    }
  | ProjectBuild of {
      options: build_options;
      error_reporting_mode: error_reporting_mode;
    }
  | ProjectTest of {
      options: test_options;
      error_reporting_mode: error_reporting_mode;
    }
[@@deriving eq]

let check_leftovers (arglist: arglist): unit =
  if (arglist_size arglist) > 0 then
    err "There are leftover arguments."
  else
    ()

let parse_mod_source (s: string): mod_source =
  let ss = String.split_on_char ',' s in
  match ss with
  | [path] ->
     ModuleBodySource { body_path = path }
  | [inter_path; body_path] ->
     ModuleSource { inter_path = inter_path; body_path = body_path }
  | _ ->
     Errors.invalid_module_source s

let parse_entrypoint (s: string): entrypoint =
  let ss = String.split_on_char ':' s in
  match ss with
  | [mn; i] ->
     Entrypoint (make_mod_name mn, make_ident i)
  | _ ->
     Errors.invalid_entrypoint s

let parse_executable_target (arglist: arglist): (arglist * target) =
  (* Get the --entrypoint *)
  match pop_value_flag arglist "entrypoint" with
  | Some (arglist, entrypoint) ->
     (match pop_value_flag arglist "output" with
      | Some (arglist, bin_path) ->
         (arglist, Executable { bin_path = bin_path; entrypoint = parse_entrypoint entrypoint })
      | None ->
         Errors.missing_output ())
  | None ->
     (match pop_bool_flag arglist "no-entrypoint" with
      | Some _ ->
         Errors.no_entrypoint_wrong_target ()
      | None ->
         Errors.missing_entrypoint ())

let get_output (arglist: arglist): (arglist * string) =
  match pop_value_flag arglist "output" with
  | Some (arglist, output_path) ->
     (arglist, output_path)
  | None ->
     Errors.missing_output ()

let parse_c_target (arglist: arglist): (arglist * target) =
  (* Get the --entrypoint *)
  match pop_value_flag arglist "entrypoint" with
  | Some (arglist, entrypoint) ->
     (* An entrypoint was passed in. *)
     let (arglist, output_path) = get_output arglist in
     (arglist, CStandalone { output_path = output_path; entrypoint = Some (parse_entrypoint entrypoint) })
  | None ->
     (* No --entrypoint. Did we get the --no-entrypoint flag? *)
     (match pop_bool_flag arglist "no-entrypoint" with
      | Some arglist ->
         let (arglist, output_path) = get_output arglist in
         (arglist, CStandalone { output_path = output_path; entrypoint = None })
      | None ->
         Errors.missing_entrypoint ())

let parse_target_type (arglist: arglist): (arglist * target) =
  match pop_value_flag arglist "target-type" with
  | Some (arglist, target_value) ->
     (* An explicit target type was passed. *)
     (match target_value with
      | "exe" | "bin" ->
         (* Build an executable binary. *)
         parse_executable_target arglist
      | "c" ->
         (* Build a standaloine C file. *)
         parse_c_target arglist
      | "tc" ->
         (* Typecheck. *)
         (arglist, TypeCheck)
      | _ ->
         Errors.unknown_target target_value)
  | None ->
     (* The default target is to build an executable binary. This means we need
        an entrypoint. *)
     parse_executable_target arglist

let parse_error_reporting_mode (arglist: arglist): (arglist * error_reporting_mode) =
  match pop_value_flag arglist "error-format" with
  | Some (arglist, value) ->
     (* An explicit error reporting mode was passed. *)
     (match value with
      | "plain" ->
         (* Report errors in plain text. *)
         (arglist, ErrorReportPlain)
      | "json" ->
         (* Report errors in JSON. *)
         (arglist, ErrorReportJson)
      | _ ->
         Errors.unknown_error_reporting_mode value)
  | None ->
     (* The default target is plain text errors. *)
     (arglist, ErrorReportPlain)

let parse_compile_command' (arglist: arglist): (arglist * cmd) =
  (* Parse module list *)
  let (arglist, modules): (arglist * string list) = pop_positional arglist in
  let modules: mod_source list = List.map parse_mod_source modules in
  let (arglist, error_reporting_mode) = parse_error_reporting_mode arglist in
  (* There must be at least one module. *)
  if ((List.length modules) < 1) then
    Errors.missing_module ()
  else
    (* Parse the target type. *)
    let (arglist, target): (arglist * target) = parse_target_type arglist in
    (arglist, WholeProgramCompile { modules = modules; target = target; error_reporting_mode = error_reporting_mode; })

let parse_compile_command (arglist: arglist): (arglist * cmd) =
  match pop_bool_flag arglist "help" with
  | Some arglist ->
     (arglist, CompileHelp)
  | None ->
     parse_compile_command' arglist

let parse_project_path (arglist: arglist): (arglist * string) =
  match pop_value_flag arglist "project" with
  | Some (arglist, path) ->
     (arglist, path)
  | None ->
     (arglist, "austral.json")

let parse_build_command' (arglist: arglist): (arglist * cmd) =
  let (arglist, project_path) = parse_project_path arglist in
  let (arglist, error_reporting_mode) = parse_error_reporting_mode arglist in
  let (arglist, target_type) =
    match pop_value_flag arglist "target-type" with
    | Some (arglist, target_type) ->
       (arglist, Some target_type)
    | None ->
       (arglist, None)
  in
  let (arglist, output_path) =
    match pop_value_flag arglist "output" with
    | Some (arglist, output_path) ->
       (arglist, Some output_path)
    | None ->
       (arglist, None)
  in
  let (arglist, entrypoint) =
    match pop_value_flag arglist "entrypoint" with
    | Some (arglist, entrypoint) ->
       (arglist, Some (parse_entrypoint entrypoint))
    | None ->
       (arglist, None)
  in
  let (arglist, no_entrypoint) =
    match pop_bool_flag arglist "no-entrypoint" with
    | Some arglist ->
       (arglist, true)
    | None ->
       (arglist, false)
  in
  let options = BuildOptions {
                    project_path;
                    target_type;
                    output_path;
                    entrypoint;
                    no_entrypoint;
                  }
  in
  (arglist, ProjectBuild { options; error_reporting_mode })

let parse_build_command (arglist: arglist): (arglist * cmd) =
  match pop_bool_flag arglist "help" with
  | Some arglist ->
     (arglist, BuildHelp)
  | None ->
     parse_build_command' arglist

let parse_test_command' (arglist: arglist): (arglist * cmd) =
  let (arglist, project_path) = parse_project_path arglist in
  let (arglist, error_reporting_mode) = parse_error_reporting_mode arglist in
  let (arglist, test_name) =
    match pop_value_flag arglist "name" with
    | Some (arglist, "") ->
       let _ = arglist in
       Errors.missing_test_name ()
    | Some (arglist, name) ->
       (arglist, Some name)
    | None ->
       (arglist, None)
  in
  let options = TestOptions { project_path; test_name } in
  (arglist, ProjectTest { options; error_reporting_mode })

let parse_test_command (arglist: arglist): (arglist * cmd) =
  match pop_bool_flag arglist "help" with
  | Some arglist ->
     (arglist, TestHelp)
  | None ->
     parse_test_command' arglist

let parse (arglist: arglist): cmd =
  let args: arg list = arglist_to_list arglist in
  match args with
  | [BoolFlag "help"] ->
     HelpCommand
  | [BoolFlag "version"] ->
     VersionCommand
  | (PositionalArg "compile")::rest ->
     (* Try parsing the `compile` command. *)
     let (arglist, cmd) = parse_compile_command (arglist_from_list rest) in
     let _ = check_leftovers arglist in
     cmd
  | (PositionalArg "build")::rest ->
     let (arglist, cmd) = parse_build_command (arglist_from_list rest) in
     let _ = check_leftovers arglist in
     cmd
  | (PositionalArg "test")::rest ->
     let (arglist, cmd) = parse_test_command (arglist_from_list rest) in
     let _ = check_leftovers arglist in
     cmd
  | _ ->
     HelpCommand
