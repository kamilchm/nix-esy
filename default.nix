{ pkgs, fetchFromGitHub, nodejs, git, makeWrapper,
  opam2nix ? pkgs.callPackage ./opam2nix-packages {}
}:

let esyDeps = dir:
  with builtins;
  let locked = readDir "${dir}/esy.lock/opam"; in
  let dir2dep = dir:
    let name = head (split "\\." dir); in
    let version = substring ((stringLength name) + 1) (stringLength dir) dir; in
    let dep = { inherit name; constraint = "=${version}"; }; in
    dep;
  in
  let deps = map dir2dep (attrNames locked); in
  deps;
in
let cmdliner = (opam2nix.buildOpamPackage {
    name = "cmdliner-1.0.2-8500634a";
    src = fetchFromGitHub {
      owner = "esy-ocaml";
      repo = "cmdliner";
      rev = "8500634a96019c4d29b1751628025b693f2b97d6";
      sha256 = "0dgc6dhwfvghism99v0bbbdmzs6kmsa6kgb25zjm740n3k87wlb7";
    };
  });
in
pkgs.stdenv.mkDerivation rec {
  name = "esy-${version}";
  version = "0.5.7";
  src = fetchFromGitHub {
    owner = "esy";
    repo = "esy";
    rev = "91be30dea9bc4650091f45aa184a3fab948c1e9f";
    sha256 = "0a9hrw0l8yzb45cxl1988zl4ibsych7lh4w6x75hxpxid73jpgak";
  };
  buildInputs = 
    (builtins.filter (p: p != true) (opam2nix.build {
      specs = (esyDeps src)
        ++ [ { name = "reason"; } { name = "angstrom"; } { name = "cmdliner"; constraint = "=1.0.2-8500634a"; } ];
      overrides = { self, super }: {
        opamPackages = self.opamPackages // { cmdliner = { "1.0.2-8500634a" = cmdliner; }; };
      };
    }))
    ++ [ nodejs git makeWrapper ];
  buildPhase = ''
    dune build
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
