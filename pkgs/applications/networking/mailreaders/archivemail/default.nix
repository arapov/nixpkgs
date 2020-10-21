{ lib
, fetchurl
, pythonPackages
}:

pythonPackages.buildPythonApplication rec {
  pname = "archivemail";
  version = "0.9.0";

  src = fetchurl {
    url = "mirror://sourceforge/project/${pname}/${pname}-${version}.tar.gz";
    sha256 = "0qy6dy8y2ywrdcch3w5yqw4q5bkykprywqdxcw59f93gp8phwhsb";
  };

  meta = with lib; {
    description = "Tool for archiving and compressing old email in mailboxes.";
    homepage = "http://archivemail.sourceforge.net/";
    maintainers = with maintainers; [ aarapov ];
    license = licenses.gpl3;
  };
}
