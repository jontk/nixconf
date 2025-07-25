{ config, lib, pkgs, inputs, userDotfilesConfig ? null, enabledModules ? {}, yamlStructure ? null, ... }:

with lib;

let
  cfg = userDotfilesConfig;
  yamlParser = import ../yaml-parser-simple.nix { inherit lib; };
  
  # Get dotfiles path from the flake input
  dotfilesPath = inputs.dotfiles.outPath;
  
  # Priority mode for kubernetes module
  priorityMode = 
    if cfg != null then
      cfg.priorityModes.kubernetes or "merge"
    else
      "merge";
  
  # Read kubernetes module configuration from module.yml
  kubernetesModuleConfig = yamlParser.readModuleConfig "${dotfilesPath}/modules/kubernetes/module.yml";
  
  # Use default settings for now
  profileSettings = kubernetesModuleConfig.settings;
  
  # Kubernetes configuration files from dotfiles
  kubectlAliasesFile = "${dotfilesPath}/modules/kubernetes/kubectl-aliases";
  kubectlCompletionsFile = "${dotfilesPath}/modules/kubernetes/kubectl-completions.sh";
  kubeConfigFile = "${dotfilesPath}/modules/kubernetes/kube-config";
  
  # Parse kubernetes aliases
  parseKubeAliases = content:
    let
      lines = filter (l: l != "" && !(hasPrefix "#" l)) (splitString "\n" content);
      parseAlias = line:
        let
          match = builtins.match "alias ([^=]+)='([^']+)'.*" line;
        in
        if match != null then
          { name = elemAt match 0; value = elemAt match 1; }
        else null;
      aliases = filter (a: a != null) (map parseAlias lines);
    in
    listToAttrs (map (a: nameValuePair a.name a.value) aliases);
  
  # Read and parse kubernetes aliases
  kubeAliases = 
    if builtins.pathExists kubectlAliasesFile then
      parseKubeAliases (builtins.readFile kubectlAliasesFile)
    else
      {};
  
  # Essential Kubernetes packages and tools
  kubernetesPackages = with pkgs; [
    kubectl                  # Kubernetes CLI
    kubectx                  # Switch between contexts
    kubens                   # Switch between namespaces
    kubernetes-helm          # Helm package manager
    k9s                      # Terminal UI for Kubernetes
    kustomize                # Kubernetes configuration management
    stern                    # Multi-pod log tailing
    dive                     # Docker image analyzer (useful for K8s)
  ];
  
in
{
  config = mkIf (cfg != null && cfg.enable && (hasAttr "kubernetes" enabledModules)) {
    # Shell aliases for Kubernetes development
    programs.bash.shellAliases = mkIf (priorityMode != "nixconf") 
      kubeAliases;
    
    programs.zsh.shellAliases = mkIf (priorityMode != "nixconf")
      kubeAliases;
    
    # Kubernetes environment variables
    home.sessionVariables = mkIf (priorityMode != "nixconf") {
      DOTFILES_KUBERNETES_MODULE = "active";
      DOTFILES_KUBERNETES_VERSION = kubernetesModuleConfig.version or "unknown";
      KUBECONFIG = "$HOME/.kube/config";
      KUBE_EDITOR = "\${EDITOR:-vim}";
    };
    
    # Install Kubernetes and essential tools
    home.packages = mkIf (priorityMode != "nixconf") kubernetesPackages;
    
    # Kubectl completions for bash
    programs.bash.initExtra = mkIf (priorityMode != "nixconf") ''
      # Enable kubectl completion
      if command -v kubectl >/dev/null 2>&1; then
        source <(kubectl completion bash)
        complete -F __start_kubectl k  # Make 'k' alias work with completion
      fi
      
      # Kubernetes helper functions
      kns() {
        if [[ $# -eq 0 ]]; then
          kubectl config view --minify --output 'jsonpath={..namespace}'
          echo
        else
          kubectl config set-context --current --namespace="$1"
        fi
      }
      
      kctx() {
        if [[ $# -eq 0 ]]; then
          kubectl config current-context
        else
          kubectl config use-context "$1"
        fi
      }
      
      # Get all resources in namespace
      kgetall() {
        local namespace="''${1:-default}"
        kubectl get all --namespace="$namespace"
      }
      
      # Pod shell access
      ksh() {
        local pod="$1"
        local container="''${2:-}"
        if [[ -z "$pod" ]]; then
          echo "Usage: ksh <pod-name> [container-name]"
          return 1
        fi
        
        if [[ -n "$container" ]]; then
          kubectl exec -it "$pod" -c "$container" -- /bin/bash || kubectl exec -it "$pod" -c "$container" -- /bin/sh
        else
          kubectl exec -it "$pod" -- /bin/bash || kubectl exec -it "$pod" -- /bin/sh
        fi
      }
      
      # Watch pods
      kwatch() {
        local namespace="''${1:---all-namespaces}"
        if [[ "$namespace" == "--all-namespaces" ]]; then
          kubectl get pods --all-namespaces --watch
        else
          kubectl get pods --namespace="$namespace" --watch
        fi
      }
    '';
    
    # Kubectl completions for zsh
    programs.zsh.initExtra = mkIf (priorityMode != "nixconf") ''
      # Enable kubectl completion
      if command -v kubectl >/dev/null 2>&1; then
        source <(kubectl completion zsh)
        complete -F __start_kubectl k  # Make 'k' alias work with completion
      fi
      
      # Kubernetes helper functions
      kns() {
        if [[ $# -eq 0 ]]; then
          kubectl config view --minify --output 'jsonpath={..namespace}'
          echo
        else
          kubectl config set-context --current --namespace="$1"
        fi
      }
      
      kctx() {
        if [[ $# -eq 0 ]]; then
          kubectl config current-context
        else
          kubectl config use-context "$1"
        fi
      }
      
      # Get all resources in namespace
      kgetall() {
        local namespace="''${1:-default}"
        kubectl get all --namespace="$namespace"
      }
      
      # Pod shell access
      ksh() {
        local pod="$1"
        local container="''${2:-}"
        if [[ -z "$pod" ]]; then
          echo "Usage: ksh <pod-name> [container-name]"
          return 1
        fi
        
        if [[ -n "$container" ]]; then
          kubectl exec -it "$pod" -c "$container" -- /bin/bash || kubectl exec -it "$pod" -c "$container" -- /bin/sh
        else
          kubectl exec -it "$pod" -- /bin/bash || kubectl exec -it "$pod" -- /bin/sh
        fi
      }
      
      # Watch pods
      kwatch() {
        local namespace="''${1:---all-namespaces}"
        if [[ "$namespace" == "--all-namespaces" ]]; then
          kubectl get pods --all-namespaces --watch
        else
          kubectl get pods --namespace="$namespace" --watch
        fi
      }
    '';
    
    # Create .kube directory structure
    home.activation.setupKubeDir = mkIf (priorityMode != "nixconf") (
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        $DRY_RUN_CMD mkdir -p "$HOME/.kube"
      ''
    );
  };
}