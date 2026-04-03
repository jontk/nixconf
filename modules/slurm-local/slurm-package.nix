{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "slurm";
  version = "25.11.2";

  src = pkgs.fetchurl {
    url = "https://download.schedmd.com/slurm/slurm-${version}.tar.bz2";
    sha256 = "0faxrv4wxl4p2cc7531gn72b2j5mhsjvs56bw3b6h4kcfi7q9zcv";
  };

  # CRITICAL: SLURM plugins use dlopen with RTLD_LAZY to resolve symbols
  # from the parent binary (slurmctld/slurmd) at runtime. Nix's bindnow
  # hardening forces immediate symbol resolution which breaks this.
  hardeningDisable = [ "bindnow" ];

  nativeBuildInputs = with pkgs; [
    pkg-config
    libtool
    python3
    perl
  ];

  buildInputs = with pkgs; [
    munge
    json_c
    libyaml
    http-parser
    openssl
    pam
    libjwt
    libmysqlclient
    readline
    curl
    dbus
    libbpf
    ncurses
    lz4
    hwloc
    numactl
  ];

  configureFlags = [
    "--sysconfdir=/etc/slurm"
    "--localstatedir=/var"
    "--enable-pam"
    "--with-munge=${pkgs.munge}"
    "--with-http-parser=${pkgs.http-parser}"
    "--with-json=${pkgs.lib.getDev pkgs.json_c}"
    "--with-yaml=${pkgs.lib.getDev pkgs.libyaml}"
    "--with-jwt=${pkgs.libjwt}"
    "--with-lz4=${pkgs.lib.getDev pkgs.lz4}"
    "--with-hwloc=${pkgs.lib.getDev pkgs.hwloc}"
    "--with-bpf=${pkgs.libbpf}"
    "--without-rpath"
    "--enable-slurmrestd"
  ];

  preConfigure = ''
    patchShebangs ./doc/html/shtml2html.py
    patchShebangs ./doc/man/man2html.py
  '';

  enableParallelBuilding = true;

  postInstall = ''
    rm -f $out/lib/*.la $out/lib/slurm/*.la
  '';

  meta = with pkgs.lib; {
    description = "SLURM Workload Manager 25.11.2";
    homepage = "https://www.schedmd.com/";
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
