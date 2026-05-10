(*
   Part of the Austral project, under the Apache License v2.0 with LLVM Exceptions.
   See LICENSE file for details.

   SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
*)
open CliParser
open Error

module StringMap = Map.Make(String)

module Errors = struct
  let invalid_project ~path ~message =
    austral_raise CliError [
      Text "Invalid Austral project file ";
      Code path;
      Text ".";
      Break;
      Text message
    ]

  let invalid_json ~path ~message =
    invalid_project ~path ~message:("Could not parse JSON: " ^ message)

  let expected_object ~path =
    invalid_project ~path ~message:"The project file root must be a JSON object."

  let expected_field ~path ~field ~expected =
    invalid_project ~path ~message:("Field `" ^ field ^ "` must be " ^ expected ^ ".")

  let missing_field ~path ~field =
    invalid_project ~path ~message:("Missing required field `" ^ field ^ "`.")

  let missing_entrypoint ~path ~name =
    invalid_project ~path ~message:("Target `" ^ name ^ "` must define an entrypoint.")

  let source_dir_not_found ~path ~dir =
    invalid_project ~path ~message:("Source directory `" ^ dir ^ "` does not exist.")

  let interface_without_body ~path ~inter_path =
    invalid_project ~path ~message:("Interface file `" ^ inter_path ^ "` has no matching module body.")

  let no_modules ~path =
    invalid_project ~path ~message:"No Austral modules were found."

  let no_tests ~path =
    invalid_project ~path ~message:"The project file defines no tests."

  let unknown_target ~path ~target =
    invalid_project ~path ~message:("Unknown target type `" ^ target ^ "`.")

  let unknown_test ~path ~name =
    invalid_project ~path ~message:("Unknown test `" ^ name ^ "`.")

  let no_entrypoint_wrong_target ~path =
    invalid_project ~path ~message:"`no-entrypoint` requires target type `c`."
end

type source_config =
  SourceConfig of {
      source_directories: string list;
      modules: string list;
    }

type target_config =
  TargetConfig of {
      source_directories: string list;
      modules: string list;
      target_type: string option;
      output_path: string option;
      entrypoint: entrypoint option;
    }

type test_config =
  TestConfig of {
      test_name: string;
      source_directories: string list;
      modules: string list;
      output_path: string option;
      entrypoint: entrypoint option;
    }

type project =
  Project of {
      path: string;
      base_dir: string;
      package_name: string option;
      package_version: string option;
      build: target_config;
      tests: test_config list;
    }

type build_spec =
  BuildSpec of {
      modules: mod_source list;
      target: target;
    }

type test_spec =
  TestSpec of {
      test_name: string;
      modules: mod_source list;
      output_path: string;
      entrypoint: entrypoint;
    }

let assoc_opt (field: string) (json: Yojson.Basic.t): Yojson.Basic.t option =
  match json with
  | `Assoc fields -> List.assoc_opt field fields
  | _ -> None

let object_field_opt ~(path: string) ~(field: string) (json: Yojson.Basic.t): Yojson.Basic.t option =
  match assoc_opt field json with
  | Some (`Assoc _) as value ->
     value
  | Some _ ->
     Errors.expected_field ~path ~field ~expected:"an object"
  | None ->
     None

let string_field_opt ~(path: string) ~(field: string) (json: Yojson.Basic.t): string option =
  match assoc_opt field json with
  | Some (`String value) ->
     Some value
  | Some _ ->
     Errors.expected_field ~path ~field ~expected:"a string"
  | None ->
     None

let string_list_field ~(path: string) ~(field: string) ~(default: string list) (json: Yojson.Basic.t): string list =
  match assoc_opt field json with
  | Some (`List values) ->
     List.map
       (function
        | `String value -> value
        | _ -> Errors.expected_field ~path ~field ~expected:"an array of strings")
       values
  | Some _ ->
     Errors.expected_field ~path ~field ~expected:"an array of strings"
  | None ->
     default

let test_list_field ~(path: string) (json: Yojson.Basic.t): Yojson.Basic.t list =
  match assoc_opt "tests" json with
  | Some (`List values) ->
     values
  | Some _ ->
     Errors.expected_field ~path ~field:"tests" ~expected:"an array of objects"
  | None ->
     []

let parse_entrypoint_field ~(path: string) ~(field: string) (json: Yojson.Basic.t): entrypoint option =
  match string_field_opt ~path ~field json with
  | Some value ->
     Some (parse_entrypoint value)
  | None ->
     None

let parse_source_config ~(path: string) (json: Yojson.Basic.t): source_config =
  SourceConfig {
      source_directories = string_list_field ~path ~field:"sourceDirectories" ~default:["src"] json;
      modules = string_list_field ~path ~field:"modules" ~default:[] json;
    }

let parse_target_config ~(path: string) ~(common: source_config) (json: Yojson.Basic.t): target_config =
  let (SourceConfig { source_directories; modules }) = common in
  TargetConfig {
      source_directories = string_list_field ~path ~field:"sourceDirectories" ~default:source_directories json;
      modules = string_list_field ~path ~field:"modules" ~default:modules json;
      target_type = string_field_opt ~path ~field:"targetType" json;
      output_path = string_field_opt ~path ~field:"output" json;
      entrypoint = parse_entrypoint_field ~path ~field:"entrypoint" json;
    }

let parse_test_config ~(path: string) ~(common: source_config) (json: Yojson.Basic.t): test_config =
  let (SourceConfig { source_directories; modules }) = common in
  let name =
    match string_field_opt ~path ~field:"name" json with
    | Some name -> name
    | None -> Errors.missing_field ~path ~field:"tests[].name"
  in
  TestConfig {
      test_name = name;
      source_directories = string_list_field ~path ~field:"sourceDirectories" ~default:source_directories json;
      modules = string_list_field ~path ~field:"modules" ~default:modules json;
      output_path = string_field_opt ~path ~field:"output" json;
      entrypoint = parse_entrypoint_field ~path ~field:"entrypoint" json;
    }

let load (path: string): project =
  let json =
    try Yojson.Basic.from_file path with
    | Sys_error message -> Errors.invalid_project ~path ~message
    | Yojson.Json_error message -> Errors.invalid_json ~path ~message
  in
  match json with
  | `Assoc _ ->
     let base_dir = Filename.dirname path in
     let package_name = string_field_opt ~path ~field:"name" json in
     let package_version = string_field_opt ~path ~field:"version" json in
     let common = parse_source_config ~path json in
     let build_json =
       match object_field_opt ~path ~field:"build" json with
       | Some build_json -> build_json
       | None -> json
     in
     let build = parse_target_config ~path ~common build_json in
     let tests = List.map (parse_test_config ~path ~common) (test_list_field ~path json) in
     Project {
         path;
         base_dir;
         package_name;
         package_version;
         build;
         tests;
       }
  | _ ->
     Errors.expected_object ~path

let resolve_path (base_dir: string) (path: string): string =
  if Filename.is_relative path then
    Filename.concat base_dir path
  else
    path

let resolve_module_source (base_dir: string) (source: mod_source): mod_source =
  match source with
  | ModuleSource { inter_path; body_path } ->
     ModuleSource {
         inter_path = resolve_path base_dir inter_path;
         body_path = resolve_path base_dir body_path;
       }
  | ModuleBodySource { body_path } ->
     ModuleBodySource {
         body_path = resolve_path base_dir body_path;
       }

let path_exists (path: string): bool =
  Sys.file_exists path

let is_directory (path: string): bool =
  path_exists path && (Unix.stat path).st_kind = Unix.S_DIR

let rec list_files_rec (dir: string): string list =
  let names = Array.to_list (Sys.readdir dir) in
  let names = List.sort String.compare names in
  List.concat (List.map
                 (fun name ->
                   let path = Filename.concat dir name in
                   if is_directory path then
                     list_files_rec path
                   else
                     [path])
                 names)

type module_pair =
  ModulePair of {
      inter_path: string option;
      body_path: string option;
    }

let add_module_file (pairs: module_pair StringMap.t) (path: string): module_pair StringMap.t =
  let ext = Filename.extension path in
  if ext = ".aui" || ext = ".aum" then
    let stem = Filename.remove_extension path in
    let current =
      match StringMap.find_opt stem pairs with
      | Some pair -> pair
      | None -> ModulePair { inter_path = None; body_path = None }
    in
    let (ModulePair { inter_path; body_path }) = current in
    let next =
      if ext = ".aui" then
        ModulePair { inter_path = Some path; body_path }
      else
        ModulePair { inter_path; body_path = Some path }
    in
    StringMap.add stem next pairs
  else
    pairs

let module_source_of_pair ~(path: string) (_stem: string) (pair: module_pair): mod_source =
  let (ModulePair { inter_path; body_path }) = pair in
  match inter_path, body_path with
  | Some inter_path, Some body_path ->
     ModuleSource { inter_path; body_path }
  | None, Some body_path ->
     ModuleBodySource { body_path }
  | Some inter_path, None ->
     Errors.interface_without_body ~path ~inter_path
  | None, None ->
     internal_err "Empty module pair in project discovery."

let discover_modules ~(path: string) (source_directories: string list): mod_source list =
  let files =
    List.concat
      (List.map
         (fun dir ->
           if is_directory dir then
             list_files_rec dir
           else
             Errors.source_dir_not_found ~path ~dir)
         source_directories)
  in
  let pairs = List.fold_left add_module_file StringMap.empty files in
  StringMap.bindings pairs
  |> List.map (fun (stem, pair) -> module_source_of_pair ~path stem pair)

let modules_from_config ~(path: string) ~(base_dir: string) (source_directories: string list) (modules: string list): mod_source list =
  let result =
    match modules with
    | [] ->
       let source_directories = List.map (resolve_path base_dir) source_directories in
       discover_modules ~path source_directories
    | modules ->
       modules
       |> List.map parse_mod_source
       |> List.map (resolve_module_source base_dir)
  in
  match result with
  | [] -> Errors.no_modules ~path
  | _ -> result

let default_output ~(package_name: string option) ~(target_name: string) ~(target_type: string): string =
  let name =
    match package_name with
    | Some name -> name
    | None -> target_name
  in
  match target_type with
  | "c" -> Filename.concat "build" (name ^ ".c")
  | _ -> Filename.concat "build" name

let make_target ~(path: string) ~(base_dir: string) ~(package_name: string option) ~(target_name: string) ~(config: target_config) ~(options: build_options): target =
  let (TargetConfig { target_type; output_path; entrypoint; _ }) = config in
  let (BuildOptions { target_type = target_type_override; output_path = output_override; entrypoint = entrypoint_override; no_entrypoint; _ }) = options in
  let entrypoint =
    if no_entrypoint then
      None
    else
      match entrypoint_override with
      | Some entrypoint -> Some entrypoint
      | None -> entrypoint
  in
  let target_type =
    match target_type_override with
    | Some target_type -> target_type
    | None ->
       match target_type with
       | Some target_type -> target_type
       | None ->
          if no_entrypoint then
            "c"
          else
            match entrypoint with
            | Some _ -> "exe"
            | None -> "tc"
  in
  let (output, output_is_cli_override) =
    match output_override with
    | Some path -> (path, true)
    | None ->
       match output_path with
       | Some path -> (path, false)
       | None -> (default_output ~package_name ~target_name ~target_type, false)
  in
  let resolve_output output =
    if output_is_cli_override then
      output
    else
      resolve_path base_dir output
  in
  match target_type with
  | "tc" ->
     TypeCheck
  | "exe" | "bin" ->
     (match entrypoint with
      | Some entrypoint ->
         Executable { bin_path = resolve_output output; entrypoint }
      | None ->
         Errors.missing_entrypoint ~path ~name:target_name)
  | "c" ->
     (match entrypoint with
      | Some entrypoint ->
         CStandalone { output_path = resolve_output output; entrypoint = Some entrypoint }
      | None ->
         if no_entrypoint || Option.is_none entrypoint then
           CStandalone { output_path = resolve_output output; entrypoint = None }
         else
           Errors.no_entrypoint_wrong_target ~path)
  | other ->
     Errors.unknown_target ~path ~target:other

let build_spec (project: project) (options: build_options): build_spec =
  let (Project { path; base_dir; package_name; build; _ }) = project in
  let (TargetConfig { source_directories; modules; _ }) = build in
  BuildSpec {
      modules = modules_from_config ~path ~base_dir source_directories modules;
      target = make_target ~path ~base_dir ~package_name ~target_name:"build" ~config:build ~options;
    }

let test_spec_of_config ~(path: string) ~(base_dir: string) ~(package_name: string option) (config: test_config): test_spec =
  let (TestConfig { test_name; source_directories; modules; output_path; entrypoint }) = config in
  let entrypoint =
    match entrypoint with
    | Some entrypoint -> entrypoint
    | None -> Errors.missing_entrypoint ~path ~name:test_name
  in
  let output_path =
    match output_path with
    | Some output_path -> output_path
    | None ->
       let package =
         match package_name with
         | Some name -> name
         | None -> "austral"
       in
       Filename.concat "build" (package ^ "-" ^ test_name)
  in
  TestSpec {
      test_name;
      modules = modules_from_config ~path ~base_dir source_directories modules;
      output_path = resolve_path base_dir output_path;
      entrypoint;
    }

let test_specs (project: project) (options: test_options): test_spec list =
  let (Project { path; base_dir; package_name; tests; _ }) = project in
  let (TestOptions { test_name; _ }) = options in
  match tests, test_name with
  | [], _ ->
     Errors.no_tests ~path
  | tests, None ->
     List.map (test_spec_of_config ~path ~base_dir ~package_name) tests
  | tests, Some name ->
     match List.filter (fun (TestConfig { test_name; _ }) -> test_name = name) tests with
     | [] -> Errors.unknown_test ~path ~name
     | selected -> List.map (test_spec_of_config ~path ~base_dir ~package_name) selected
