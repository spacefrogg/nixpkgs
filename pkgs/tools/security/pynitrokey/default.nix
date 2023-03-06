{ python3Packages, lib, nrfutil  }:

with python3Packages;

buildPythonApplication rec {
  pname = "pynitrokey";
  version = "0.4.33";
  format = "flit";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-NL6eXtK3XGXuayC2qnUMkcAhksWW/NwYV5S1AvSxrRc=";
  };

  patches = [ ./deps.diff ];

  propagatedBuildInputs = [
    click
    cryptography
    ecdsa
    fido2
    frozendict
    intelhex
    nrfutil
    pyserial
    pyusb
    requests
    pygments
    python-dateutil
    spsdk
    tlv8
    urllib3
    cffi
    cbor
    nkdfu
  ];

  # spsdk is patched to allow for newer cryptography
  postPatch = ''
    substituteInPlace pyproject.toml \
        --replace "cryptography >=3.4.4,<37" "cryptography"
  '';

  # no tests
  doCheck = false;

  pythonImportsCheck = [ "pynitrokey" ];

  meta = with lib; {
    description = "Python client for Nitrokey devices";
    homepage = "https://github.com/Nitrokey/pynitrokey";
    license = with licenses; [ asl20 mit ];
    maintainers = with maintainers; [ frogamic ];
    mainProgram = "nitropy";
  };
}
