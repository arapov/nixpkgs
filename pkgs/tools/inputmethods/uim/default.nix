{ lib, stdenv, fetchFromGitHub, shared-mime-info
, autoconf, automake, intltool, libtool, pkgconfig, cmake
, ruby, librsvg
, ncurses, m17n_lib, m17n_db, expat
, withAnthy ? true, anthy ? null
, withGtk ? true
, withGtk2 ? withGtk, gtk2 ? null
, withGtk3 ? withGtk, gtk3 ? null
, withQt ? true
, withQt4 ? withQt, qt4 ? null
, withQt5 ? false, qt5 ? null
, withLibnotify ? true, libnotify ? null
, withSqlite ? true, sqlite ? null
, withNetworking ? true, curl ? null, openssl ? null
, withFFI ? true, libffi ? null

# Things that are clearly an overkill to be enabled by default
, withMisc ? false, libeb ? null
}:

with lib;

assert withGtk2 -> gtk2 != null;
assert withGtk3 -> gtk3 != null;

# TODO(@oxij): ./configure can't find both qmakes at the same time
# this can be fixed by adding an alias qmake -> qmaka${version} in qmake derivation
assert withQt4 -> !withQt5 && qt4 != null;
assert withQt5 -> !withQt4 && qt5 != null;

assert !withQt5; # fails to build with "Makefile.qmake: No such file or directory"

assert withAnthy -> anthy != null;
assert withLibnotify -> libnotify != null;
assert withSqlite -> sqlite != null;
assert withNetworking -> curl != null && openssl != null;
assert withFFI -> libffi != null;
assert withMisc -> libeb != null;

stdenv.mkDerivation rec {
  version = "1.8.8";
  pname = "uim";

  src = fetchFromGitHub {
    owner = "uim";
    repo = "uim";
    rev = "2c0958c9c505a87e70e344c2192e2e5123c71ea5";
    fetchSubmodules = true;
    sha256 = "1hkjxi5r49gcna37m3jvykny5hz9ram4y8a3q7lw4qzr52mz9pdp";
  };

  nativeBuildInputs = [
    autoconf automake intltool libtool pkgconfig cmake

    ruby # used by sigscheme build to generate function tables
    librsvg # used by uim build to generate png pixmaps from svg
  ];

  buildInputs = [
    ncurses m17n_lib m17n_db expat
  ]
  ++ optional withAnthy anthy
  ++ optional withGtk2 gtk2
  ++ optional withGtk3 gtk3
  ++ optional withQt4 qt4
  ++ optionals withQt5 [ qt5.qtbase.bin qt5.qtbase.dev ]
  ++ optional withLibnotify libnotify
  ++ optional withSqlite sqlite
  ++ optionals withNetworking [
    curl openssl
  ]
  ++ optional withFFI libffi
  ++ optional withMisc libeb;

  prePatch = ''
    patchShebangs *.sh */*.sh */*/*.sh

    # configure sigscheme in maintainer mode or else some function tables won't get autogenerated
    substituteInPlace configure.ac \
      --replace "--with-master-pkg=uim --enable-conf=uim" \
                "--enable-maintainer-mode --with-master-pkg=uim --enable-conf=uim"

    # generate ./configure files
    (cd sigscheme/libgcroots; ./autogen.sh)
    (cd sigscheme; ./autogen.sh)
    ./autogen.sh
  '';

  patches = [ ./data-hook.patch ];

  configureFlags = [
    # configure in maintainer mode or else some pixmaps won't get autogenerated
    # this should imply the above `--enable-maintainer-mode`, but it does not
    "--enable-maintainer-mode"

    "--enable-pref"
    "--with-skk"
    "--with-x"
    "--with-xft"
    "--with-expat=${expat.dev}"
  ]
  ++ optional withAnthy "--with-anthy-utf8"
  ++ optional withGtk2 "--with-gtk2"
  ++ optional withGtk3 "--with-gtk3"
  ++ optionals withQt4 [
    "--with-qt4"
    "--with-qt4-immodule"
  ]
  ++ optionals withQt5 [
    "--with-qt5"
    "--with-qt5-immodule"
  ]
  ++ optional withLibnotify "--enable-notify=libnotify"
  ++ optional withSqlite "--with-sqlite3"
  ++ optionals withNetworking [
    "--with-curl"
    "--with-openssl-dir=${openssl.dev}"
  ]
  ++ optional withFFI "--with-ffi"
  ++ optional withMisc "--with-eb";

  # TODO: things in `./configure --help`, but not in nixpkgs
  #--with-canna            Use Canna [default=no]
  #--with-wnn              Build with libwnn [default=no]
  #--with-mana             Build a plugin for Mana [default=yes]
  #--with-prime            Build a plugin for PRIME [default=yes]
  #--with-sj3              Use SJ3 [default=no]
  #--with-osx-dcs          Build with OS X Dictionary Services [default=no]

  # TODO: fix this in librsvg/glib later
  # https://github.com/NixOS/nixpkgs/pull/57027#issuecomment-475461733
  preBuild = ''
    export XDG_DATA_DIRS="${shared-mime-info}/share"
  '';

  dontUseCmakeConfigure = true;

  meta = with lib; {
    homepage    = src.meta.homepage;
    description = "A multilingual input method framework";
    license     = licenses.bsd3;
    platforms   = platforms.unix;
    broken      = stdenv.hostPlatform.isAarch64; # fails to build libgcroots (not supported on aarch64)
    maintainers = with maintainers; [ ericsagnes oxij ];
  };
}
