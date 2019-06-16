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
  name = "cmdliner-1.0.2";
  src = fetchFromGitHub {
    owner = "esy-ocaml";
    repo = "cmdliner";
    rev = "8500634a96019c4d29b1751628025b693f2b97d6";
    sha256 = "0dgc6dhwfvghism99v0bbbdmzs6kmsa6kgb25zjm740n3k87wlb7";
  };
});
in
let mccs = (opam2nix.buildOpamPackage {
  name = "mccs-1.1+9";
  src = fetchFromGitHub {
    owner = "andreypopp";
    repo = "ocaml-mccs";
    rev = "45d0224eec75fdc3120b8e389709beacfb1cb9f7";
    sha256 = "0fjfknbzxmv2zc9xsfl4cmd2lp2zf10gq0aspi4g0qk26rmma41i";
  };
});
in
let esy-solve-cudf = pkgs.stdenv.mkDerivation rec {
  name = "esy-solve-cudf-${version}";
  version = "0.1.10";
  src = fetchFromGitHub {
    owner = "andreypopp";
    repo = "esy-solve-cudf";
    rev = "v${version}";
    sha256 = "1ky2mkyl676bxphyx0d3vqr58za185nq46h0lai89631g94ia1d7";
  };
  buildInputs = [
    (opam2nix.build {
      specs = [ { name = "cudf"; } { name = "cmdliner"; } { name = "mccs"; constraint = "=${mccs.version}"; } ];
      overrides = { super, self }: {
        opamPackages = super.opamPackages // { mccs = { "${mccs.version}" = mccs; }; };
      };
    })
  ] ++ [ makeWrapper ];
  buildPhase = ''
    dune build
  '';
  installPhase = ''
    mkdir -p $out/_build/default/bin
    cp _build/default/bin/esySolveCudfCommand.exe $out/_build/default/bin/esySolveCudfCommand.exe
    chmod +x $out/_build/default/bin/esySolveCudfCommand.exe

    mkdir $out/bin
    makeWrapper $out/_build/default/bin/esySolveCudfCommand.exe $out/bin/esySolveCudfCommand
  '';
};
in
pkgs.stdenv.mkDerivation rec {
  name = "esy-${version}";
  version = "0.5.8";
  src = fetchFromGitHub {
    owner = "esy";
    repo = "esy";
    rev = "v${version}";
    sha256 = "0n2606ci86vqs7sm8icf6077h5k6638909rxyj43lh55ah33l382";
  };
  buildInputs = 
    (builtins.filter (p: p != true) (opam2nix.build {
      specs = (esyDeps src)
        ++ [ { name = "reason"; } { name = "angstrom"; } { name = "cmdliner"; constraint = "=${cmdliner.version}"; } ];
      overrides = { super, self }: {
        opamPackages = super.opamPackages // { cmdliner = { "${cmdliner.version}" = cmdliner; }; };
      };
    }))
    ++ [ nodejs git makeWrapper ];
  buildPhase = ''
    dune build
    node scripts/make-release-skeleton.js ${version}
  '';
  installPhase = ''
    cp -R _release/* $out/
    cp _build/default/bin/esy.exe $out/_build/default/bin/esy.exe
    chmod +x $out/_build/default/bin/esy.exe

    cp _build/default/esy-build-package/bin/*.exe \
       $out/_build/default/esy-build-package/bin
    chmod +x $out/_build/default/esy-build-package/bin/*.exe
    
    cp bin/esyInstallRelease.js $out/_build/default/bin/

    mkdir $out/bin
    makeWrapper $out/_build/default/bin/esy.exe $out/bin/esy \
      --set "ESY__SOLVE_CUDF_COMMAND" "${esy-solve-cudf}/bin/esySolveCudfCommand"
  '';
}
