{ lib
, buildPythonPackage
, fetchPypi
, flit-core
, python
, pythonOlder
}:

buildPythonPackage rec {
  pname = "tlv8";
  version = "0.10.0";
  format = "setuptools";

  disabled = pythonOlder "3.6";

  src = fetchPypi {
    pname = "tlv8";
    inherit version;
    hash = "sha256-eTClkCZ7gJlSJyrCon7oG5nsUZH6LroIBQ4NruQmJoQ=";
  };

  # Tests are not part of PyPI releases. GitHub source can't be used
  # as it ends with an infinite recursion
  doCheck = false;

  pythonImportsCheck = [
    "tlv8"
  ];

  meta = with lib; {
    description = "Type-Length-Value8 codec";
    homepage = "https://github.com/jlusiardi/tlv8_python";
    license = licenses.asl20;
    maintainers = with maintainers; [ spacefrogg ];
  };
}
