{ fetchurl }:
rec {
  version = "1.8.7";
  src = fetchurl {
    url = "https://www.openafs.org/dl/openafs/${version}/openafs-${version}-src.tar.bz2";
    sha256 = "sha256-U1Q6Vh/OZ3FP7J8qa/QIxcwdBhx9ydFFlFgnXozL+nk=";
  };

  srcs = [ src
    (fetchurl {
      url = "https://www.openafs.org/dl/openafs/${version}/openafs-${version}-doc.tar.bz2";
    sha256 = "sha256-1hOE79zhqsq90YkAYq2nQcDgrrTMlzgRpJPc2m9KMX8=";
    })];
}
