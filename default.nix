{ pkgs, fetchFromGitHub, nodejs, git, makeWrapper,
  opam2nix ? pkgs.callPackage ./opam2nix-packages {}
}:

pkgs.stdenv.mkDerivation rec {
  name = "esy-${version}";
  version = "0.5.7";
  src = fetchFromGitHub {
    owner = "esy";
    repo = "esy";
    rev = "v${version}";
    sha256 = "12sz136brwphfpn1h3ch2ryyk0zfrrlmwpk9csv2s4biwkxg4p4q";
  };
  buildInputs = opam2nix.build {
    specs = opam2nix.toSpecs [
      "angstrom" "bos" { name = "cmdliner"; constraint = "=1.0.2"; } "cudf" "dose3" "dune" "fmt" "fpath"
      "lambda-term" "logs" "lwt" "lwt_ppx" "menhir" "opam-core"
      "opam-file-format" "opam-format" "opam-state" "ppx_deriving"
      "ppx_deriving_yojson" "ppx_expect" "ppx_inline_test" "ppx_let"
      "ppx_sexp_conv" "re" "reason" "yojson"
    ];
  } ++ [ nodejs git makeWrapper ];
  buildPhase = ''
    dune build -p esy,esy-build-package
    node scripts/make-release-skeleton.js
  '';
  installPhase = ''
    cp -R _release/* $out/
    cp _build/default/bin/esy.exe $out/_build/default/bin/esy.exe
    chmod +x $out/_build/default/bin/esy.exe
    cp _build/default/esy-build-package/bin/*.exe \
       $out/_build/default/esy-build-package/bin/
    chmod +x $out/_build/default/esy-build-package/bin/*.exe
    cp bin/esyInstallRelease.js $out/_build/default/bin/

    mkdir $out/bin
    makeWrapper $out/_build/default/bin/esy.exe $out/bin/esy
  '';
}
