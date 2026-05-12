(*
   Part of the Austral project, under the Apache License v2.0 with LLVM Exceptions.
   See LICENSE file for details.

   SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
*)
open OUnit2
open Austral_core.CliEngine
open Austral_core.CliParser
open Austral_core.Error

let write_file path contents =
  let stream = open_out path in
  Printf.fprintf stream "%s" contents;
  close_out stream

let temp_dir name =
  let path = Filename.temp_file name "" in
  Sys.remove path;
  Unix.mkdir path 0o755;
  path

let run_test_name project_path test_name =
  try
    exec (ProjectTest {
        options = TestOptions {
            project_path;
            test_name = Some test_name;
          };
        error_reporting_mode = ErrorReportPlain;
      })
  with Austral_error error ->
    assert_failure (render_error_to_plain error)

let make_project () =
  let root = temp_dir "austral_project_test_" in
  let project_path = Filename.concat root "austral.json" in
  write_file (Filename.concat root "Pass.aum") {|
module body Pass is
    function main(): ExitCode is
        printLn("project test ok");
        return ExitSuccess();
    end;
end module body.
|};
  write_file (Filename.concat root "CompileOnly.aum") {|
module body CompileOnly is
    function main(): ExitCode is
        abort("compile-only test should not run");
        return ExitSuccess();
    end;
end module body.
|};
  write_file (Filename.concat root "Bad.aum") {|
module body Bad is
    function main(): ExitCode is
        let x: Int32 := true;
        return ExitSuccess();
    end;
end module body.
|};
  write_file (Filename.concat root "pass.out") "project test ok";
  write_file project_path {|
{
  "name": "project-test",
  "tests": [
    {
      "name": "stdout",
      "modules": ["Pass.aum"],
      "entrypoint": "Pass:main",
      "expectedStdout": "pass.out"
    },
    {
      "name": "compile-only",
      "modules": ["CompileOnly.aum"],
      "entrypoint": "CompileOnly:main",
      "run": false
    },
    {
      "name": "compile-fail",
      "modules": ["Bad.aum"],
      "targetType": "tc",
      "expect": "compile-fail"
    }
  ]
}
|};
  project_path

let test_project_test_modes _ =
  let project_path = make_project () in
  run_test_name project_path "stdout";
  run_test_name project_path "compile-only";
  run_test_name project_path "compile-fail"

let suite =
  "ProjectTestCommand" >::: [
      "project test modes" >:: test_project_test_modes;
    ]

let _ = run_test_tt_main suite
