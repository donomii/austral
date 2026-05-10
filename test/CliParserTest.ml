(*
   Part of the Austral project, under the Apache License v2.0 with LLVM Exceptions.
   See LICENSE file for details.

   SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
*)
open OUnit2
open Austral_core.Identifier
open Austral_core.CliUtil
open Austral_core.CliParser

let parse_cmd (args: string list): cmd =
  parse (parse_args args)

let test_help_cmd _ =
  let cmd: cmd = parse_cmd ["austral"; "--help"] in
  assert_equal cmd HelpCommand

let test_version_cmd _ =
  let cmd: cmd = parse_cmd ["austral"; "--version"] in
  assert_equal cmd VersionCommand

let test_compile_help_cmd _ =
  let cmd: cmd = parse_cmd ["austral"; "compile"; "--help"] in
  assert_equal cmd CompileHelp

let test_compile_default _ =
  let cmd: cmd = parse_cmd ["austral"; "compile"; "foo.aum"; "bar.aui,bar.aum"; "--entrypoint=Foo:main"; "--output=out"]
  and expected: cmd = WholeProgramCompile {
                          modules = [
                            ModuleBodySource { body_path = "foo.aum" };
                            ModuleSource { inter_path = "bar.aui"; body_path = "bar.aum" };
                          ];
                          target = Executable {
                                       bin_path = "out";
                                       entrypoint = Entrypoint (make_mod_name "Foo", make_ident "main")
                                     };
                          error_reporting_mode = ErrorReportPlain
                        }
  in
  assert_bool "commands are equal" (equal_cmd cmd expected)

let test_build_default _ =
  let cmd: cmd = parse_cmd ["austral"; "build"]
  and expected: cmd = ProjectBuild {
                          options = BuildOptions {
                                        project_path = "austral.json";
                                        target_type = None;
                                        output_path = None;
                                        entrypoint = None;
                                        no_entrypoint = false;
                                      };
                          error_reporting_mode = ErrorReportPlain;
                        }
  in
  assert_bool "commands are equal" (equal_cmd cmd expected)

let test_build_overrides _ =
  let cmd: cmd = parse_cmd [
                     "austral";
                     "build";
                     "--project=project.json";
                     "--target-type=tc";
                     "--output=ignored";
                     "--entrypoint=Demo:main";
                     "--no-entrypoint";
                     "--error-format=json"
                   ]
  and expected: cmd = ProjectBuild {
                          options = BuildOptions {
                                        project_path = "project.json";
                                        target_type = Some "tc";
                                        output_path = Some "ignored";
                                        entrypoint = Some (Entrypoint (make_mod_name "Demo", make_ident "main"));
                                        no_entrypoint = true;
                                      };
                          error_reporting_mode = ErrorReportJson;
                        }
  in
  assert_bool "commands are equal" (equal_cmd cmd expected)

let test_project_test _ =
  let cmd: cmd = parse_cmd ["austral"; "test"; "--project=project.json"; "--name=unit"]
  and expected: cmd = ProjectTest {
                          options = TestOptions {
                                        project_path = "project.json";
                                        test_name = Some "unit";
                                      };
                          error_reporting_mode = ErrorReportPlain;
                        }
  in
  assert_bool "commands are equal" (equal_cmd cmd expected)

let suite =
  "CliParser" >::: [
      "--help" >:: test_help_cmd;
      "--version" >:: test_version_cmd;
      "compile --help" >:: test_compile_help_cmd;
      "compile default" >:: test_compile_default;
      "build default" >:: test_build_default;
      "build overrides" >:: test_build_overrides;
      "test" >:: test_project_test;
    ]

let _ = run_test_tt_main suite
