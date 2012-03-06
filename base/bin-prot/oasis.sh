#!/usr/bin/env bash
set -e -u -o pipefail

source ../../build-common.sh

cat >$HERE/_oasis <<EOF
#AUTOGENERATED FILE; EDIT oasis.sh INSTEAD
OASISFormat:  0.2
OCamlVersion: >= 3.12
Name:         bin_prot
Version:      1.3.2
Synopsis:     binary protocol generator
Authors:      Markus Mottl,
              Jane street capital
Copyrights:   (C) 2008-2011 Jane Street Capital LLC
License:      LGPL-2.1 with OCaml linking exception
LicenseFile:  LICENSE
Plugins:      StdFiles (0.2),
              DevFiles (0.2),
              META (0.2)
BuildTools:   ocamlbuild
Description:  binary protocol generator
XStdFilesAUTHORS: false
XStdFilesINSTALLFilename: INSTALL
XStdFilesREADME: false


PreBuildCommand: mkdir -p _build; cp lib/*.mlh lib/*.h _build/

Library bin_prot
  Path:               lib
  #Pack:               true
  Modules:            Binable,
                      Nat0,
                      Common,
                      Unsafe_common,
                      Unsafe_write_c,
                      Unsafe_read_c,
                      Size,
                      Write_ml,
                      Read_ml,
                      Write_c,
                      Read_c,
                      Std,
                      Type_class,
                      Map_to_safe,
                      Utils
  CSources:           common_stubs.c,
                      common_stubs.h,
                      int64_native.h,
                      write_stubs.c,
                      read_stubs.c
  BuildDepends:       unix,bigarray


Library pa_bin_prot
  Path:               syntax
  FindlibName:        syntax
  FindlibParent:      bin_prot
  modules:            Pa_bin_prot
  BuildDepends:       camlp4,camlp4.lib,camlp4.quotations,type-conv (>= 2.0.1)
  XMETAType:          syntax
  XMETARequires:      type-conv
  XMETADescription:   Syntax extension for binary protocol generator

$(declare_tests_flag)

Executable test_runner
  Path:               lib_test
  MainIs:             test_runner.ml
  Build\$:            flag(tests)
  Install:            false
  CompiledObject:     best
  Custom:             true
  BuildDepends:       bin_prot,bin_prot.syntax,oUnit (>= 1.0.2)

Test test_runner
  Run\$:              flag(tests)
  Command:           \$test_runner
  WorkingDirectory:   lib_test

Executable mac_test
  Path:               lib_test
  MainIs:             mac_test.ml
  Build\$:            flag(tests)
  Install:            false
  Custom:             true
  CompiledObject:     best
  BuildDepends:       bin_prot,bin_prot.syntax

Test mac_test
  Run\$:              flag(tests)
  Command:           \$mac_test
  WorkingDirectory:   lib_test

Executable example
  Path:               lib_test
  MainIs:             example.ml
  Build\$:            flag(tests)
  Install:            false
  BuildDepends:       bin_prot,bin_prot.syntax

Document "bin-prot"
  Title:                API reference for bin-prot
  Type:                 ocamlbuild (0.2)
  BuildTools+:          ocamldoc
  XOCamlbuildPath:      lib
  XOCamlbuildLibraries: bin_prot
EOF

make_tags $HERE/_tags <<EOF
# remove this part when oasis supports Pack: true
$(tag_for_pack Bin_prot $HERE/lib/*.ml)

<lib/read_ml.ml{i,}>: pp(cpp -undef -traditional -Werror -I.)
<lib/size.ml{i,}>: pp(cpp -undef -traditional -Werror -I.)
<lib/type_class.ml{i,}>: pp(cpp -undef -traditional -Werror -I.)
<lib/unsafe_read_c.ml{i,}>: pp(cpp -undef -traditional -Werror -I.)
<lib/write_ml.ml{i,}>: pp(cpp -undef -traditional -Werror -I.)
<lib_test/*.ml{,i}>: syntax_camlp4o
<syntax/pa_bin_prot.ml>: syntax_camlp4o
EOF

cd $HERE
rm -f setup.ml
oasis setup
enable_pack_in_setup_ml bin_prot

./configure "$@"

