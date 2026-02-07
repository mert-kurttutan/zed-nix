{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  alsa-lib,
  fontconfig,
  gnutar,
  gzip,
  libxkbcommon,
  makeWrapper,
  openssl,
  vulkan-loader,
  wayland,
  xorg,
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
    fontconfig
    libxkbcommon
    openssl
    stdenv.cc.cc
    vulkan-loader
    wayland
    xorg.libX11
    xorg.libxcb
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

    makeWrapper "$zed_bin" "$out/bin/zed" \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          vulkan-loader
          wayland
          libxkbcommon
          xorg.libX11
          xorg.libxcb
        ]
      }

    mkdir -p "$out/share/applications"
    cat > "$out/share/applications/zed.desktop" <<'EOF'
    [Desktop Entry]
    Version=1.0
    Type=Application
    Name=$APP_NAME
    GenericName=Text Editor
    Comment=A high-performance, multiplayer code editor.
    TryExec=$APP_CLI
    StartupNotify=$DO_STARTUP_NOTIFY
    Exec=$APP_CLI $APP_ARGS
    Icon=$APP_ICON
    Categories=Utility;TextEditor;Development;IDE;
    Keywords=zed;
    # To add Zed to "Open Folder With..." context menu, add `inode/directory` to the MimeType field (semicolon separated)
    # Arch linux users have reported this setting Zed as default file browser. See https://github.com/zed-industries/zed/pull/39076 and related issues.
    # If this happens to you, an unconfirmed fix may be to install Arch's `gnome-defaults-list` package.
    MimeType=text/plain;application/x-zerosize;x-scheme-handler/zed;
    Actions=NewWorkspace;

    [Desktop Action NewWorkspace]
    Exec=$APP_CLI --new $APP_ARGS
    Name=Open a new workspace

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
