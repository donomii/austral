(lang dune 3.8)
(using menhir 2.0)

(name austral)
(version 0.0.1)

(package
 (name austral)
 (synopsis "The bootstrapping compiler for Austral")
 (description "The bootstrapping compiler for Austral.")
 (authors "Fernando Borretti")
 (maintainers "Fernando Borretti <fernando@borretti.me>")
 (license "Apache-2.0 WITH LLVM-exception")
 (homepage https://austral-lang.org/)
 (bug_reports https://github.com/austral/austral/issues)
 (depends
  (ocaml (and (>= 4.14.0) (< 5.4.0)))
  (ppxlib (and (>= 0.34.0) (< 0.38.0)))
  (ppx_deriving (and (>= 6.0.3) (< 6.2.0)))
  (ppx_sexp_conv (and (>= v0.16.0) (< v0.18)))
  (sexplib (and (>= v0.16.0) (< v0.18)))
  (ounit2 (>= 2.2.7))
  (menhir (>= 20230608))
  (zarith (>= 1.12))
  (yojson (>= 2.1.0))))

(generate_opam_files)
