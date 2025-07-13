# Security tools overlays and hardened packages

final: prev: {
  # Hardened Firefox with security extensions
  firefox-hardened = prev.firefox.override {
    cfg = {
      # Enable security features
      enableTridactyl = true;
    };
    extraPrefs = ''
      // Security preferences
      user_pref("privacy.trackingprotection.enabled", true);
      user_pref("privacy.trackingprotection.socialtracking.enabled", true);
      user_pref("privacy.trackingprotection.cryptomining.enabled", true);
      user_pref("privacy.trackingprotection.fingerprinting.enabled", true);
      
      // Disable telemetry
      user_pref("toolkit.telemetry.enabled", false);
      user_pref("toolkit.telemetry.unified", false);
      user_pref("toolkit.telemetry.archive.enabled", false);
      user_pref("datareporting.healthreport.uploadEnabled", false);
      user_pref("datareporting.policy.dataSubmissionEnabled", false);
      
      // DNS over HTTPS
      user_pref("network.trr.mode", 2);
      user_pref("network.trr.uri", "https://mozilla.cloudflare-dns.com/dns-query");
      
      // Disable WebRTC
      user_pref("media.peerconnection.enabled", false);
      
      // Enhanced security
      user_pref("security.tls.version.min", 3);
      user_pref("security.ssl.require_safe_negotiation", true);
      user_pref("security.ssl.treat_unsafe_negotiation_as_broken", true);
    '';
  };

  # Enhanced SSH with security configurations
  openssh-hardened = prev.openssh.overrideAttrs (oldAttrs: {
    configureFlags = oldAttrs.configureFlags ++ [
      "--with-sandbox=rlimit"
      "--with-privsep-user=sshd"
    ];
  });

  # Security toolkit bundle
  security-tools = prev.buildEnv {
    name = "security-toolkit";
    paths = with final; [
      # Network security
      nmap
      masscan
      zmap
      rustscan
      
      # Web security
      dirb
      gobuster
      ffuf
      httpx
      
      # Cryptography
      gnupg
      age
      sops
      
      # Password management
      pass
      bitwarden-cli
      
      # Network analysis
      wireshark
      tcpdump
      netcat
      socat
      
      # System security
      lynis
      rkhunter
      aide
      
      # Forensics
      foremost
      binwalk
      exiftool
      
      # Reverse engineering
      radare2
      ghidra-bin
      john
      hashcat
    ];
  };

  # Hardened kernel packages
  linux-hardened-custom = prev.linux_hardened.override {
    structuredExtraConfig = with prev.lib.kernel; {
      # Security features
      SECURITY = yes;
      SECURITY_SELINUX = yes;
      SECURITY_APPARMOR = yes;
      SECURITY_YAMA = yes;
      
      # Kernel hardening
      SLAB_FREELIST_RANDOM = yes;
      SLAB_FREELIST_HARDENED = yes;
      SHUFFLE_PAGE_ALLOCATOR = yes;
      
      # Control flow integrity
      CFI_CLANG = whenAttr "CFI_CLANG" yes;
      
      # Stack protection
      STACKPROTECTOR = yes;
      STACKPROTECTOR_STRONG = yes;
      
      # Address space layout randomization
      RANDOMIZE_BASE = yes;
      RANDOMIZE_MEMORY = yes;
      
      # Disable dangerous features
      DEVMEM = no;
      DEVKMEM = no;
      PROC_KCORE = no;
      
      # Module signing
      MODULE_SIG = yes;
      MODULE_SIG_ALL = yes;
      MODULE_SIG_SHA512 = yes;
    };
  };

  # Tor browser with additional privacy
  tor-browser-hardened = prev.tor-browser-bundle-bin.override {
    mediaSupport = false; # Disable media codecs for privacy
  };

  # Enhanced GPG with better defaults
  gnupg-enhanced = prev.gnupg.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      # Create hardened GPG configuration
      mkdir -p $out/share/gnupg
      cat > $out/share/gnupg/gpg.conf << EOF
      # Enhanced security defaults
      personal-cipher-preferences AES256 AES192 AES
      personal-digest-preferences SHA512 SHA384 SHA256
      personal-compress-preferences ZLIB BZIP2 ZIP Uncompressed
      default-preference-list SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed
      cert-digest-algo SHA512
      s2k-digest-algo SHA512
      s2k-cipher-algo AES256
      charset utf-8
      fixed-list-mode
      no-comments
      no-emit-version
      keyid-format 0xlong
      list-options show-uid-validity
      verify-options show-uid-validity
      with-fingerprint
      require-cross-certification
      no-symkey-cache
      use-agent
      throw-keyids
      EOF
    '';
  });

  # Secure DNS resolver
  unbound-hardened = prev.unbound.overrideAttrs (oldAttrs: {
    configureFlags = oldAttrs.configureFlags ++ [
      "--enable-dnscrypt"
      "--enable-dnstap"
      "--with-libhiredis"
    ];
  });

  # Privacy-focused email client
  thunderbird-hardened = prev.thunderbird.override {
    extraPrefs = ''
      // Privacy preferences
      user_pref("privacy.donottrackheader.enabled", true);
      user_pref("mailnews.headers.showSender", true);
      user_pref("mailnews.headers.showUserAgent", false);
      user_pref("mail.collect_email_address_outgoing", false);
      user_pref("mail.collect_addressbook", "");
      
      // Security preferences
      user_pref("security.tls.version.min", 3);
      user_pref("mail.smtpserver.default.try_ssl", 3);
      user_pref("mail.server.default.check_new_mail", false);
      
      // Disable telemetry
      user_pref("toolkit.telemetry.enabled", false);
      user_pref("datareporting.healthreport.uploadEnabled", false);
    '';
  };

  # VPN tools bundle
  vpn-tools = prev.buildEnv {
    name = "vpn-tools";
    paths = with final; [
      wireguard-tools
      openvpn
      strongswan
      
      # VPN clients
      mullvad-vpn
      protonvpn-cli
    ] ++ prev.lib.optionals prev.stdenv.isLinux [
      networkmanager-openvpn
      networkmanager-vpnc
    ];
  };

  # Container security tools
  container-security = prev.buildEnv {
    name = "container-security";
    paths = with final; [
      dive
      trivy
      grype
      syft
      
      # Policy and compliance
      opa
      conftest
      
      # Runtime security
      falco
    ];
  };

  # Backup and encryption tools
  backup-security = prev.buildEnv {
    name = "backup-security";
    paths = with final; [
      restic
      borgbackup
      rclone
      
      # Encryption
      age
      sops
      rage
      
      # File integrity
      mtree
      aide
      
      # Secure deletion
      secure-delete
    ];
  };
}