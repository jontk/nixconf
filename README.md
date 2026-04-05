# NixConf

NixOS and macOS system configurations managed with Nix flakes, Home Manager, and modular NixOS modules.

## Hosts

| Host | System | Description |
|------|--------|-------------|
| `nixos-dev` | x86_64-linux | Primary NixOS workstation (Sway, NVIDIA RTX 4060, SLURM) |
| `devbox` | x86_64-linux | Secondary NixOS machine |
| `macos-laptop` | x86_64-darwin | macOS laptop via nix-darwin |

## Quick Start

```bash
# Clone
git clone https://github.com/jontk/nixconf.git
cd nixconf

# Setup secrets (NixOS only, required before first build)
sudo ./scripts/setup-secrets.sh

# Build and switch (NixOS)
sudo nixos-rebuild switch --flake '.#nixos-dev'

# Build and switch (macOS via nix-darwin)
darwin-rebuild switch --flake '.#macos-laptop'

# Or for Home Manager only
home-manager switch --flake '.#jontk@nixos-dev'
```

## Repository Structure

```
nixconf/
├── flake.nix                 # Flake inputs, outputs, host definitions
├── hosts/
│   ├── nixos-dev/            # Primary workstation config
│   ├── devbox/               # Secondary machine config
│   ├── macos-laptop/         # macOS config
│   └── example/              # Template for new hosts
├── modules/
│   ├── common/               # Cross-platform base config
│   ├── desktop/              # Sway, NVIDIA, Wayland, GUI apps
│   ├── development/          # Languages, tools, containers
│   ├── remote-access/        # SSH, RustDesk, fail2ban
│   ├── security/             # Firewall hardening, PAM
│   ├── containers/           # k3s, ArgoCD, Harbor
│   ├── networking/           # WireGuard, DNS, network config
│   ├── monitoring/           # Prometheus, Grafana, Loki
│   ├── services/             # Databases, web servers
│   ├── slurm-local/          # Local SLURM 25.11.2 cluster
│   │   ├── default.nix       # Module: munge, slurmctld, slurmdbd, slurmd, slurmrestd
│   │   ├── slurm-package.nix # Builds SLURM 25.11.2 from source
│   │   └── jobs/             # Example sbatch scripts
│   ├── performance/          # CPU, memory, I/O tuning
│   ├── maintenance/          # Auto-updates, cleanup
│   ├── snapshots/            # Btrfs snapshot management
│   ├── backup-scheduler/     # Automated backups
│   ├── secrets/              # sops-nix integration
│   └── dotfiles-integration/ # chezmoi integration
├── users/
│   └── jontk/                # Home Manager user config
├── scripts/
│   └── setup-secrets.sh      # Initial machine secret provisioning
├── k8s/                      # Git submodule (nixconf-k8s, private)
├── overlays/                 # Package overrides
└── packages/                 # Custom package definitions
```

## Secrets

Passwords are stored in `/etc/nixos/secrets/` on each machine, never in the repo.

```bash
# Run on fresh machines before first nixos-rebuild
sudo ./scripts/setup-secrets.sh
```

Required files:
- `/etc/nixos/secrets/jontk-password-hash` - User password hash
- `/etc/nixos/secrets/root-password-hash` - Root password hash

## SLURM Local Cluster

A local SLURM 25.11.2 cluster for development and testing, built from source as a NixOS module.

| Component | Port | Description |
|-----------|------|-------------|
| slurmctld | 6817 | Controller daemon |
| slurmdbd | 6819 | Database daemon (MariaDB backend) |
| slurmrestd | 6820 | REST API with JWT auth |
| slurmd node1 | 6818 | CPU compute node |
| slurmd node2 | 6821 | GPU compute node (GRES) |

Partitions: `normal` (CPU), `gpu` (GPU with GRES/TRES tracking), `all` (both nodes).

```bash
# Submit jobs
sbatch modules/slurm-local/jobs/basic_job.sh
sbatch modules/slurm-local/jobs/gpu_job.sh

# Check cluster
sinfo
squeue
sacct
```

Enable/disable in host config:
```nix
services.slurm-local.enable = true;
```

## Key Details

- **Desktop**: Sway (Wayland) with `--unsupported-gpu` for NVIDIA
- **GPU**: NVIDIA RTX 4060 (nvidia-open drivers, container toolkit)
- **Dotfiles**: Managed by chezmoi (`~/.local/share/chezmoi/`)
- **Keyboard**: GB (UK) layout
- **K8s manifests**: Separate private repo via git submodule at `k8s/`

## Common Commands

```bash
# Rebuild NixOS
sudo nixos-rebuild switch --flake '.#nixos-dev'

# Rebuild macOS (nix-darwin)
darwin-rebuild switch --flake '.#macos-laptop'

# Home Manager only
home-manager switch --flake '.#jontk@nixos-dev'

# Update flake inputs
nix flake update

# Enter dev shell
nix develop

# Check flake
nix flake check
```

## System Management

```bash
# Build without switching (test first)
sudo nixos-rebuild build --flake '.#nixos-dev'    # NixOS
darwin-rebuild build --flake '.#macos-laptop'      # macOS

# Switch to new configuration
sudo nixos-rebuild switch --flake '.#nixos-dev'    # NixOS
darwin-rebuild switch --flake '.#macos-laptop'      # macOS

# Update all flake inputs
nix flake update

# Update a single input
nix flake lock --update-input nixpkgs

# List system generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Switch to a specific generation
sudo nix-env --switch-generation 42 --profile /nix/var/nix/profiles/system
```

## Development Environments

```bash
# Enter the default dev shell
nix develop

# Run a command in the dev environment
nix develop -c rustc --version

# Try a package without installing
nix shell nixpkgs#htop

# Search for packages
nix search nixpkgs neovim

# Show flake outputs
nix flake show
```

## Package Management

```bash
# List installed system packages
nix-store -q --requisites /run/current-system | grep -v '\.drv$'

# Check why a package is installed (reverse dependencies)
nix-store -q --referrers /nix/store/<hash>-<package>

# Show package info
nix eval nixpkgs#<package>.version

# Build a specific package from the flake
nix build .#packages.x86_64-linux.<package>
```

## Adding a New Host

1. Copy the example host:
   ```bash
   cp -r hosts/example hosts/my-host
   ```

2. Edit `hosts/my-host/default.nix` — set hostname, user, hardware config.

3. Generate hardware config:
   ```bash
   sudo nixos-generate-config --root /mnt --dir hosts/my-host/
   ```

4. Add to `flake.nix` under `hostConfigs`:
   ```nix
   my-host = {
     system = "x86_64-linux";
     modules = [
       ./hosts/my-host
       home-manager.nixosModules.home-manager
     ] ++ commonModules ++ developmentModules;
   };
   ```

5. Setup secrets and build:
   ```bash
   sudo ./scripts/setup-secrets.sh
   sudo nixos-rebuild switch --flake '.#my-host'
   ```

## Creating Custom Modules

Modules follow the standard NixOS options/config pattern:

```nix
# modules/my-module/default.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.modules.myModule;
in
{
  options.modules.myModule = {
    enable = lib.mkEnableOption "my custom module";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.hello;
      description = "Package to install";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
```

Then import it in `flake.nix` and enable it in your host config.

## Nix Store Maintenance

```bash
# Clean up old generations (keep last 7 days)
sudo nix-collect-garbage --delete-older-than 7d

# Delete all old generations (aggressive)
sudo nix-collect-garbage -d

# Optimize nix store (deduplication, saves disk space)
nix-store --optimise

# Verify store integrity
nix-store --verify --check-contents

# Check nix store disk usage
du -sh /nix/store

# Show what keeps a store path alive
nix-store -q --roots /nix/store/<hash>-<package>
```

## Secrets with sops-nix

For more advanced secrets management beyond `hashedPasswordFile`, this repo includes sops-nix integration:

```nix
# Encrypt a secret
sops secrets/my-secret.yaml

# Reference in NixOS config
sops.secrets.my-secret = {
  sopsFile = ./secrets/my-secret.yaml;
  owner = "myuser";
  mode = "0400";
};

# Use the secret path in a service
services.myService.passwordFile = config.sops.secrets.my-secret.path;
```

## Custom Packages

```nix
# packages/my-app/default.nix
{ stdenv, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "my-app";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "myuser";
    repo = "my-app";
    rev = "v${version}";
    hash = "sha256-...";
  };

  installPhase = ''
    mkdir -p $out/bin
    cp my-app $out/bin/
  '';
}
```

## Overlays

Override or extend existing packages:

```nix
# overlays/default.nix
final: prev: {
  my-package = prev.my-package.overrideAttrs (old: {
    version = "2.0.0";
    src = prev.fetchurl { ... };
  });
}
```

## Troubleshooting

### Build Errors

```bash
# Get detailed trace
sudo nixos-rebuild switch --flake '.#nixos-dev' --show-trace

# Dry build (check what would be built)
nix build .#nixosConfigurations.nixos-dev.config.system.build.toplevel --dry-run

# Enter repl to inspect config
nix repl
> :lf .
> outputs.nixosConfigurations.nixos-dev.config.services.slurm-local.enable
```

### Switch Lock Issues

If `nixos-rebuild switch` fails with "Could not acquire lock" or "Unit already loaded":

```bash
sudo systemctl reset-failed nixos-rebuild-switch-to-configuration.service
sudo nixos-rebuild switch --flake '.#nixos-dev'
```

### Disk Space

```bash
# Emergency cleanup
sudo nix-collect-garbage -d
sudo nix-store --optimise
du -sh /nix/store
df -h /
```

### Evaluation Errors

```bash
# Check flake validity
nix flake check

# Evaluate a specific option
nix eval .#nixosConfigurations.nixos-dev.config.services.openssh.enable

# Use --impure if reading from /etc
nix build --impure .#nixosConfigurations.nixos-dev.config.system.build.toplevel
```

### SLURM Node Down

If a SLURM node shows as `down*`:

```bash
sudo systemctl restart slurm-local-slurmd-node1  # or node2
sudo scontrol update NodeName=node1 State=DOWN Reason="reset"
sudo scontrol update NodeName=node1 State=RESUME
```

## Performance Tips

```nix
# In your host config or flake.nix
nix.settings = {
  # Use all cores for builds
  max-jobs = "auto";
  cores = 0;

  # Binary caches (faster rebuilds)
  substituters = [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
  ];

  # Auto-optimize store on every build
  auto-optimise-store = true;
};
```

## Resources

### Official Documentation
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Reference Manual](https://nixos.org/manual/nix/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [nix-darwin Manual](https://daiderd.com/nix-darwin/manual/index.html)

### Learning
- [Zero to Nix](https://zero-to-nix.com/) — Modern introduction to Nix
- [Nix Pills](https://nixos.org/guides/nix-pills/) — Deep dive into Nix concepts
- [nix.dev](https://nix.dev/) — Practical tutorials
- [NixOS Wiki](https://nixos.wiki/) — Community documentation

### Community
- [NixOS Discourse](https://discourse.nixos.org/)
- [NixOS Matrix/IRC](https://nixos.org/community/)
- [r/NixOS](https://reddit.com/r/NixOS)

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit with conventional commits (`feat:`, `fix:`, `docs:`, `chore:`)
4. Open a Pull Request

## License

MIT
