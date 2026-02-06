{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, alsa-lib
, gnutar
, gzip
, makeWrapper
}:

let
  version = "0.222.4";
  src = fetchurl {
    url = "https://github.com/zed-industries/zed/releases/download/v${version}/zed-linux-x86_64.tar.gz";
    sha256 = "sha256-c4VRYfETlc3bd7GDfqrxN00CiQBlcXxCPNGb1arAXj4=";
  };

in
stdenv.mkDerivation {
  pname = "zed";
  inherit version src;

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    gnutar
    gzip
    makeWrapper
  ];
  buildInputs = [
    alsa-lib
    stdenv.cc.cc
  ];

  buildPhase = ''
    runHook preBuild
    mkdir -p build
    tar -xzf $src -C build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/opt/zed $out/bin
    cp -r build/* $out/opt/zed/

    zed_bin=$(find $out/opt/zed -type f -name zed -perm -u+x | head -n 1)
    if [ -z "$zed_bin" ]; then
      echo "zed binary not found in extracted archive" >&2
      exit 1
    fi

    ln -s "$zed_bin" $out/bin/zed
    runHook postInstall
  '';

  meta = with lib; {
    description = "Zed editor (prebuilt binary)";
    homepage = "https://zed.dev";
    license = licenses.unfreeRedistributable;
    platforms = [ "x86_64-linux" ];
    mainProgram = "zed";
  };
}
