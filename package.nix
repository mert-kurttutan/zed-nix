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
  libx11,
  libxcb,
  makeWrapper,
  openssl,
  vulkan-loader,
  wayland,
}:

let
  version = "v0.225.9";
  src = fetchurl {
    url = "https://github.com/zed-industries/zed/releases/download/v${version}/zed-linux-x86_64.tar.gz";
    sha256 = "sha256-0CcYhZ/xdz62m3yb/qq5LgrX5zD1vViBgZeNrjJRHoU=";
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
    libx11
    libxcb
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
          libx11
          libxcb
        ]
      }

    mkdir -p "$out/share/applications"
    install -Dm644 ${./assets/app-icon-nightly.png} \
      "$out/share/icons/hicolor/256x256/apps/zed.png"
    cat > "$out/share/applications/zed.desktop" <<'EOF'
    [Desktop Entry]
    Version=1.0
    Type=Application
    Name=Zed
    GenericName=Text Editor
    Comment=A high-performance, multiplayer code editor.
    TryExec=zed
    Exec=zed %U
    Icon=zed
    Categories=Utility;TextEditor;Development;IDE;
    Keywords=zed;
    # To add Zed to "Open Folder With..." context menu, add `inode/directory` to the MimeType field (semicolon separated)
    # Arch linux users have reported this setting Zed as default file browser. See https://github.com/zed-industries/zed/pull/39076 and related issues.
    # If this happens to you, an unconfirmed fix may be to install Arch's `gnome-defaults-list` package.
    MimeType=text/plain;application/x-zerosize;x-scheme-handler/zed;
    Actions=NewWorkspace;

    [Desktop Action NewWorkspace]
    Exec=zed --new %U
    Name=Open a new workspace
EOF

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
