(*
   Part of the Austral project, under the Apache License v2.0 with LLVM Exceptions.
   See LICENSE file for details.

   SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
*)
open OUnit2
open Austral_core.Identifier
open Austral_core.CliParser
open Austral_core.Error
open Austral_core.Project

let write_file path contents =
  let stream = open_out path in
  Printf.fprintf stream "%s" contents;
  close_out stream

let temp_dir name =
  let path = Filename.temp_file name "" in
  Sys.remove path;
  Unix.mkdir path 0o755;
  path

let mkdir parent name =
  let path = Filename.concat parent name in
  Unix.mkdir path 0o755;
  path

let assert_austral_error f =
  try
    let _ = f () in
    assert_failure "Expected an Austral_error"
  with Austral_error _ ->
    ()

let test_discovered_build _ =
  let root = temp_dir "austral_project_" in
  let src = mkdir root "src" in
  let project_path = Filename.concat root "austral.json" in
  let inter_path = Filename.concat src "Main.aui" in
  let body_path = Filename.concat src "Main.aum" in
  let helper_path = Filename.concat src "Helper.aum" in
  write_file inter_path "module Main is\nend module.\n";
  write_file body_path "module body Main is\nend module body.\n";
  write_file helper_path "module body Helper is\nend module body.\n";
  write_file project_path {|
{
  "name": "demo",
  "sourceDirectories": ["src"],
  "build": {
    "entrypoint": "Main:main"
  }
}
|};
  let project = load project_path in
  let options = BuildOptions {
                    project_path;
                    target_type = None;
                    output_path = None;
                    entrypoint = None;
                    no_entrypoint = false;
                  }
  in
  let (BuildSpec { modules; target }) = build_spec project options in
  let expected_modules = [
      ModuleBodySource { body_path = helper_path };
      ModuleSource { inter_path; body_path };
    ]
  in
  assert_bool "modules are discovered and paired" (List.for_all2 equal_mod_source modules expected_modules);
  let expected_target =
    Executable {
        bin_path = Filename.concat root "build/demo";
        entrypoint = Entrypoint (make_mod_name "Main", make_ident "main");
      }
  in
  assert_bool "target is executable" (equal_target target expected_target)

let test_discovered_build_uses_import_order _ =
  let root = temp_dir "austral_project_" in
  let src = mkdir root "src" in
  let project_path = Filename.concat root "austral.json" in
  let main_path = Filename.concat src "AMain.aum" in
  let dep_path = Filename.concat src "ZDep.aum" in
  write_file main_path {|
import ZDep();
module body AMain is
end module body.
|};
  write_file dep_path "module body ZDep is\nend module body.\n";
  write_file project_path {|
{
  "name": "demo",
  "sourceDirectories": ["src"],
  "build": {
    "targetType": "tc"
  }
}
|};
  let project = load project_path in
  let options = BuildOptions {
                    project_path;
                    target_type = None;
                    output_path = None;
                    entrypoint = None;
                    no_entrypoint = false;
                  }
  in
  let (BuildSpec { modules; _ }) = build_spec project options in
  let expected_modules = [
      ModuleBodySource { body_path = dep_path };
      ModuleBodySource { body_path = main_path };
    ]
  in
  assert_bool "imported module appears before importer" (List.for_all2 equal_mod_source modules expected_modules)

let test_discovered_build_rejects_import_cycle _ =
  let root = temp_dir "austral_project_" in
  let src = mkdir root "src" in
  let project_path = Filename.concat root "austral.json" in
  write_file (Filename.concat src "A.aum") {|
import B();
module body A is
end module body.
|};
  write_file (Filename.concat src "B.aum") {|
import A();
module body B is
end module body.
|};
  write_file project_path {|
{
  "name": "demo",
  "sourceDirectories": ["src"],
  "build": {
    "targetType": "tc"
  }
}
|};
  let project = load project_path in
  let options = BuildOptions {
                    project_path;
                    target_type = None;
                    output_path = None;
                    entrypoint = None;
                    no_entrypoint = false;
                  }
  in
  assert_austral_error (fun _ -> build_spec project options)

let test_explicit_modules_keep_order _ =
  let root = temp_dir "austral_project_" in
  let project_path = Filename.concat root "austral.json" in
  write_file project_path {|
{
  "name": "demo",
  "modules": [
    "B.aum",
    "A.aui,A.aum"
  ],
  "build": {
    "targetType": "tc"
  }
}
|};
  let project = load project_path in
  let options = BuildOptions {
                    project_path;
                    target_type = None;
                    output_path = None;
                    entrypoint = None;
                    no_entrypoint = false;
                  }
  in
  let (BuildSpec { modules; target }) = build_spec project options in
  let expected_modules = [
      ModuleBodySource { body_path = Filename.concat root "B.aum" };
      ModuleSource {
          inter_path = Filename.concat root "A.aui";
          body_path = Filename.concat root "A.aum";
        };
    ]
  in
  assert_bool "explicit module order is preserved" (List.for_all2 equal_mod_source modules expected_modules);
  assert_bool "target is typecheck" (equal_target target TypeCheck)

let test_output_override_is_cwd_relative _ =
  let root = temp_dir "austral_project_" in
  let project_path = Filename.concat root "austral.json" in
  write_file project_path {|
{
  "name": "demo",
  "modules": ["Main.aum"],
  "build": {
    "entrypoint": "Main:main",
    "output": "build/demo"
  }
}
|};
  let project = load project_path in
  let options = BuildOptions {
                    project_path;
                    target_type = None;
                    output_path = Some "custom/out";
                    entrypoint = None;
                    no_entrypoint = false;
                  }
  in
  let (BuildSpec { target; _ }) = build_spec project options in
  let expected_target =
    Executable {
        bin_path = "custom/out";
        entrypoint = Entrypoint (make_mod_name "Main", make_ident "main");
      }
  in
  assert_bool "CLI output override is relative to cwd" (equal_target target expected_target)

let test_named_test_selection _ =
  let root = temp_dir "austral_project_" in
  let project_path = Filename.concat root "austral.json" in
  write_file project_path {|
{
  "name": "demo",
  "tests": [
    {
      "name": "unit",
      "modules": ["Test.aum"],
      "entrypoint": "Test:main"
    }
  ]
}
|};
  let project = load project_path in
  let options = TestOptions { project_path; test_name = Some "unit" } in
  match test_specs project options with
  | [TestSpec { test_name; modules; output_path; entrypoint }] ->
     assert_equal "unit" test_name;
     assert_bool "test module is resolved"
       (List.for_all2 equal_mod_source modules [ModuleBodySource { body_path = Filename.concat root "Test.aum" }]);
     assert_equal (Filename.concat root "build/demo-unit") output_path;
     assert_bool "entrypoint is parsed"
       (equal_entrypoint entrypoint (Entrypoint (make_mod_name "Test", make_ident "main")))
  | _ ->
     assert_failure "Expected one selected test"

let suite =
  "ProjectConfig" >::: [
      "discovered build" >:: test_discovered_build;
      "discovered build uses import order" >:: test_discovered_build_uses_import_order;
      "discovered build rejects import cycle" >:: test_discovered_build_rejects_import_cycle;
      "explicit modules keep order" >:: test_explicit_modules_keep_order;
      "output override is cwd relative" >:: test_output_override_is_cwd_relative;
      "named test selection" >:: test_named_test_selection;
    ]

let _ = run_test_tt_main suite
