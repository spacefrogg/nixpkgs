{ stdenv, fetchurl, pkgconfig, wrapGAppsHook, gtkmm3, gnome3, pdftk }:

stdenv.mkDerivation rec {
  name = "pdfchain-${version}";
  version = "0.4.4.2";

  src = fetchurl {
    url = "mirror://sourceforge/pdfchain/pdfchain-${version}.tar.gz";
    sha256 = "0g9gfm1wiriczbpnrkb7vs6cli8a1shw0kpyz7wwxjg8vf9hzvhy";
  };

  nativeBuildInputs = [ pkgconfig wrapGAppsHook ];
  buildInputs = [ gtkmm3 gnome3.adwaita-icon-theme ];

  outputs = [ "out" "doc" ];

  enableParallelBuilding = true;

  preConfigure = ''
    substituteInPlace src/constant.h --replace /usr/share/pixmaps/pdfchain.png $out/share/pixmaps/pdfchain.png
  '';

  preFixup = ''
    gappsWrapperArgs+=(--prefix PATH : ${stdenv.lib.makeBinPath [ pdftk ]})
  '';

  meta = with stdenv.lib; {
    description = "GTK GUI for pdftk to modify PDF documents";
    homepage = http://pdfchain.sourceforge.net;
    license = licenses.gpl3;
    maintainers = [ maintainers.spacefrogg ];
  };
}
