# Code Quality and Security Scanning Module
# Provides comprehensive code quality, security scanning, and static analysis tools

{ config, lib, pkgs, isNixOS ? pkgs.stdenv.isLinux, isDarwin ? pkgs.stdenv.isDarwin, ... }:

with lib;

let
  cfg = config.modules.development.codeQuality;

  # Pre-commit hook configuration generator
  generatePreCommitConfig = hooks: ''
    repos:
    ${lib.concatStringsSep "\n" (map (hook: ''
      - repo: ${hook.repo}
        rev: ${hook.rev}
        hooks:
        ${lib.concatStringsSep "\n" (map (h: ''
          - id: ${h.id}
            ${lib.optionalString (h ? args) "args: [${lib.concatStringsSep ", " (map (arg: "\"${arg}\"") h.args)}]"}
            ${lib.optionalString (h ? files) "files: '${h.files}'"}
            ${lib.optionalString (h ? exclude) "exclude: '${h.exclude}'"}
            ${lib.optionalString (h ? additionalDependencies) "additional_dependencies: [${lib.concatStringsSep ", " h.additionalDependencies}]"}
        '') hook.hooks)}
    '') hooks)}
  '';

  # SonarQube properties generator
  generateSonarProperties = props: ''
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "sonar.${key}=${toString value}") props)}
  '';

in

{
  options.modules.development.codeQuality = {
    enable = mkEnableOption "code quality and security scanning tools";
    
    linting = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable code linting tools";
      };
      
      languages = {
        shell = mkOption {
          type = types.bool;
          default = true;
          description = "Enable shell script linting";
        };
        
        yaml = mkOption {
          type = types.bool;
          default = true;
          description = "Enable YAML linting";
        };
        
        json = mkOption {
          type = types.bool;
          default = true;
          description = "Enable JSON linting";
        };
        
        markdown = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Markdown linting";
        };
        
        dockerfile = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Dockerfile linting";
        };
        
        terraform = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Terraform linting";
        };
        
        github = mkOption {
          type = types.bool;
          default = true;
          description = "Enable GitHub Actions linting";
        };
      };
    };
    
    formatting = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable code formatting tools";
      };
      
      prettier = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Prettier for multiple file types";
        };
        
        config = mkOption {
          type = types.attrs;
          default = {
            printWidth = 120;
            tabWidth = 2;
            useTabs = false;
            semi = true;
            singleQuote = true;
            trailingComma = "es5";
            bracketSpacing = true;
          };
          description = "Prettier configuration";
        };
      };
    };
    
    security = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable security scanning tools";
      };
      
      gitSecrets = mkOption {
        type = types.bool;
        default = true;
        description = "Enable git-secrets for preventing secrets in commits";
      };
      
      gitleaks = mkOption {
        type = types.bool;
        default = true;
        description = "Enable gitleaks for detecting secrets";
      };
      
      trivy = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Trivy for vulnerability scanning";
      };
      
      semgrep = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Semgrep for pattern-based scanning";
      };
      
      bandit = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Bandit for Python security scanning";
      };
      
      gosec = mkOption {
        type = types.bool;
        default = true;
        description = "Enable gosec for Go security scanning";
      };
    };
    
    staticAnalysis = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable static analysis tools";
      };
      
      sonarqube = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable SonarQube integration";
        };
        
        serverUrl = mkOption {
          type = types.str;
          default = "http://localhost:9000";
          description = "SonarQube server URL";
        };
        
        projectKey = mkOption {
          type = types.str;
          default = "my-project";
          description = "SonarQube project key";
        };
      };
      
      codeql = mkOption {
        type = types.bool;
        default = false;
        description = "Enable CodeQL for semantic code analysis";
      };
    };
    
    preCommit = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable pre-commit framework";
      };
      
      hooks = mkOption {
        type = types.listOf (types.submodule {
          options = {
            repo = mkOption {
              type = types.str;
              description = "Repository URL for the hooks";
            };
            
            rev = mkOption {
              type = types.str;
              description = "Revision/tag to use";
            };
            
            hooks = mkOption {
              type = types.listOf (types.submodule {
                options = {
                  id = mkOption {
                    type = types.str;
                    description = "Hook ID";
                  };
                  
                  args = mkOption {
                    type = types.listOf types.str;
                    default = [];
                    description = "Arguments to pass to the hook";
                  };
                  
                  files = mkOption {
                    type = types.str;
                    default = "";
                    description = "File pattern to match";
                  };
                  
                  exclude = mkOption {
                    type = types.str;
                    default = "";
                    description = "File pattern to exclude";
                  };
                  
                  additionalDependencies = mkOption {
                    type = types.listOf types.str;
                    default = [];
                    description = "Additional dependencies";
                  };
                };
              });
              description = "Hooks to run";
            };
          };
        });
        default = [];
        description = "Pre-commit hooks configuration";
      };
    };
    
    documentation = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable documentation tools";
      };
      
      docLinters = mkOption {
        type = types.bool;
        default = true;
        description = "Enable documentation linters";
      };
    };
  };

  config = mkIf cfg.enable {
    # Code quality tools packages
    environment.systemPackages = with pkgs;
      lib.optionals cfg.linting.languages.shell [ shellcheck bashate ]
      ++ lib.optionals cfg.linting.languages.yaml [ yamllint ]
      ++ lib.optionals cfg.linting.languages.markdown [ mdl ]
      ++ lib.optionals cfg.linting.languages.dockerfile [ hadolint ]
      ++ lib.optionals cfg.linting.languages.terraform [ tflint checkov ]
      ++ lib.optionals cfg.linting.languages.github [ actionlint ]
      ++ lib.optionals cfg.formatting.enable [ shfmt ]
      ++ [ nixpkgs-fmt treefmt ]
      ++ lib.optionals cfg.security.gitSecrets [ git-secrets ]
      ++ lib.optionals cfg.security.gitleaks [ gitleaks ]
      ++ lib.optionals cfg.security.trivy [ trivy ]
      ++ lib.optionals cfg.security.semgrep [ semgrep ]
      ++ lib.optionals cfg.security.bandit [ python313Packages.bandit ]
      ++ lib.optionals cfg.security.gosec [ gosec ]
      ++ lib.optionals cfg.staticAnalysis.enable [ sonar-scanner-cli ]
      ++ lib.optionals cfg.staticAnalysis.codeql [ codeql ]
      ++ lib.optionals cfg.preCommit.enable [ pre-commit ]
      ++ lib.optionals cfg.documentation.enable [ vale ]
      ++ lib.optionals cfg.documentation.docLinters [ markdownlint-cli ]
      ++ [
        tokei
        scc
        gource
        cargo-audit
        cargo-outdated
        bundler-audit
        python3Packages.safety
        npm-check
        pnpm-audit
        license-scanner
        lizard
        super-linter
        megalinter
        (pkgs.writeShellScriptBin "init-code-quality" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        echo "Initializing code quality tools..."
        
        # Initialize pre-commit
        if [[ -f .pre-commit-config.yaml ]]; then
          echo "Pre-commit config already exists"
        else
          cat > .pre-commit-config.yaml << 'EOF'
        ${generatePreCommitConfig cfg.preCommit.hooks}
        EOF
          echo "Created .pre-commit-config.yaml"
        fi
        
        # Install pre-commit hooks
        if command -v pre-commit >/dev/null 2>&1; then
          pre-commit install
          pre-commit install --hook-type commit-msg
          echo "Pre-commit hooks installed"
        fi
        
        # Initialize git-secrets
        if command -v git-secrets >/dev/null 2>&1; then
          git secrets --install
          git secrets --register-aws
          echo "Git-secrets configured"
        fi
        
        # Create .prettierrc if needed
        if [[ ! -f .prettierrc ]]; then
          cat > .prettierrc << 'EOF'
        ${builtins.toJSON cfg.formatting.prettier.config}
        EOF
          echo "Created .prettierrc"
        fi
        
        # Create sonar-project.properties if needed
        ${lib.optionalString cfg.staticAnalysis.sonarqube.enable ''
          if [[ ! -f sonar-project.properties ]]; then
            cat > sonar-project.properties << 'EOF'
          ${generateSonarProperties {
            projectKey = cfg.staticAnalysis.sonarqube.projectKey;
            host.url = cfg.staticAnalysis.sonarqube.serverUrl;
            sources = ".";
            exclusions = "**/*_test.go,**/vendor/**,**/node_modules/**";
          }}
          EOF
            echo "Created sonar-project.properties"
          fi
        ''}
        
        echo "Code quality tools initialized!"
      '')
      
      # Security scan helper
        (pkgs.writeShellScriptBin "security-scan" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        echo "Running security scans..."
        
        # Run gitleaks
        if command -v gitleaks >/dev/null 2>&1; then
          echo "Checking for secrets with gitleaks..."
          gitleaks detect --source . --verbose || echo "Gitleaks scan completed"
        fi
        
        # Run trivy on current directory
        if command -v trivy >/dev/null 2>&1; then
          echo "Running Trivy vulnerability scan..."
          trivy fs . || echo "Trivy scan completed"
        fi
        
        # Run Semgrep
        if command -v semgrep >/dev/null 2>&1; then
          echo "Running Semgrep analysis..."
          semgrep --config=auto . || echo "Semgrep scan completed"
        fi
        
        # Language-specific scans
        if [[ -f go.mod ]] && command -v gosec >/dev/null 2>&1; then
          echo "Running Go security scan..."
          gosec ./... || echo "Gosec scan completed"
        fi
        
        if [[ -f requirements.txt || -f setup.py ]] && command -v bandit >/dev/null 2>&1; then
          echo "Running Python security scan..."
          bandit -r . || echo "Bandit scan completed"
        fi
        
        echo "Security scans completed!"
      '')
      
      # Code quality report generator
        (pkgs.writeShellScriptBin "code-quality-report" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        REPORT_DIR="code-quality-reports"
        mkdir -p "$REPORT_DIR"
        
        echo "Generating code quality reports..."
        
        # Code statistics
        if command -v tokei >/dev/null 2>&1; then
          tokei > "$REPORT_DIR/code-stats.txt"
          echo "Code statistics saved to $REPORT_DIR/code-stats.txt"
        fi
        
        # Complexity analysis
        if command -v lizard >/dev/null 2>&1; then
          lizard -o "$REPORT_DIR/complexity.html" --html .
          echo "Complexity report saved to $REPORT_DIR/complexity.html"
        fi
        
        # Git history analysis
        if command -v gitinspector >/dev/null 2>&1; then
          gitinspector --format=html --timeline --weeks > "$REPORT_DIR/git-history.html"
          echo "Git history report saved to $REPORT_DIR/git-history.html"
        fi
        
        # Dependency audit
        echo "## Dependency Audit Report" > "$REPORT_DIR/dependencies.md"
        echo "Generated on: $(date)" >> "$REPORT_DIR/dependencies.md"
        echo "" >> "$REPORT_DIR/dependencies.md"
        
        if [[ -f Cargo.toml ]] && command -v cargo-audit >/dev/null 2>&1; then
          echo "### Rust Dependencies" >> "$REPORT_DIR/dependencies.md"
          cargo audit >> "$REPORT_DIR/dependencies.md" 2>&1 || true
          echo "" >> "$REPORT_DIR/dependencies.md"
        fi
        
        if [[ -f package.json ]] && command -v npm >/dev/null 2>&1; then
          echo "### Node.js Dependencies" >> "$REPORT_DIR/dependencies.md"
          npm audit >> "$REPORT_DIR/dependencies.md" 2>&1 || true
          echo "" >> "$REPORT_DIR/dependencies.md"
        fi
        
        echo "Code quality reports generated in $REPORT_DIR/"
      '')
      ];
    
    # Shell aliases for code quality
    environment.shellAliases = {
      # Linting shortcuts
      lint-shell = "shellcheck **/*.sh";
      lint-yaml = "yamllint .";
      lint-docker = "hadolint **/Dockerfile*";
      lint-tf = "tflint";
      lint-actions = "actionlint";
      
      # Formatting shortcuts
      fmt-shell = "shfmt -w .";
      fmt-nix = "nixpkgs-fmt .";
      fmt-pretty = "prettier --write .";
      
      # Security shortcuts
      sec-scan = "security-scan";
      sec-secrets = "gitleaks detect";
      sec-trivy = "trivy fs .";
      
      # Quality shortcuts
      qa-init = "init-code-quality";
      qa-report = "code-quality-report";
      qa-stats = "tokei";
      qa-complex = "lizard .";
      
      # Pre-commit shortcuts
      pc-run = "pre-commit run --all-files";
      pc-update = "pre-commit autoupdate";
    };
    
    # Default pre-commit hooks
    modules.development.codeQuality.preCommit.hooks = mkDefault [
      {
        repo = "https://github.com/pre-commit/pre-commit-hooks";
        rev = "v5.0.0";
        hooks = [
          { id = "trailing-whitespace"; }
          { id = "end-of-file-fixer"; }
          { id = "check-yaml"; }
          { id = "check-added-large-files"; }
          { id = "check-merge-conflict"; }
          { id = "check-json"; }
          { id = "pretty-format-json"; args = ["--autofix"]; }
          { id = "check-toml"; }
          { id = "check-xml"; }
          { id = "detect-private-key"; }
          { id = "forbid-new-submodules"; }
          { id = "mixed-line-ending"; }
        ];
      }
      {
        repo = "https://github.com/shellcheck-py/shellcheck-py";
        rev = "v0.10.0.1";
        hooks = [
          { id = "shellcheck"; }
        ];
      }
      {
        repo = "https://github.com/adrienverge/yamllint";
        rev = "v1.35.1";
        hooks = [
          { id = "yamllint"; }
        ];
      }
      {
        repo = "https://github.com/hadolint/hadolint";
        rev = "v2.13.1-beta";
        hooks = [
          { id = "hadolint-docker"; }
        ];
      }
      {
        repo = "https://github.com/gitleaks/gitleaks";
        rev = "v8.21.2";
        hooks = [
          { id = "gitleaks"; }
        ];
      }
    ];
  };
}
