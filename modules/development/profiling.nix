# Performance Profiling and Debugging Module
# Provides comprehensive performance analysis, profiling, and debugging tools

{ config, lib, pkgs, isNixOS ? pkgs.stdenv.isLinux, isDarwin ? pkgs.stdenv.isDarwin, ... }:

with lib;

let
  cfg = config.modules.development.profiling;

  # Flamegraph generation script
  generateFlamegraph = pkgs.writeShellScript "generate-flamegraph" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    COMMAND="$1"
    OUTPUT="''${2:-flamegraph.svg}"
    
    echo "Recording performance data for: $COMMAND"
    
    if command -v perf >/dev/null 2>&1; then
      # Linux perf
      perf record -F 99 -a -g -- $COMMAND
      perf script | ${pkgs.flamegraph}/bin/stackcollapse-perf.pl | ${pkgs.flamegraph}/bin/flamegraph.pl > "$OUTPUT"
    elif command -v dtrace >/dev/null 2>&1; then
      # macOS dtrace
      sudo dtrace -x ustackframes=100 -n 'profile-99 /execname == "'$COMMAND'"/ { @[ustack()] = count(); }' -c "$COMMAND"
      # Process dtrace output to flamegraph
    else
      echo "No suitable profiling tool found"
      exit 1
    fi
    
    echo "Flamegraph saved to: $OUTPUT"
  '';

in

{
  options.modules.development.profiling = {
    enable = mkEnableOption "performance profiling and debugging tools";
    
    systemProfilers = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable system-level profilers";
      };
      
      perf = mkOption {
        type = types.bool;
        default = isNixOS;
        description = "Enable Linux perf tools";
      };
      
      dtrace = mkOption {
        type = types.bool;
        default = isDarwin;
        description = "Enable DTrace (macOS)";
      };
      
      bpf = mkOption {
        type = types.bool;
        default = isNixOS;
        description = "Enable BPF tools";
      };
    };
    
    languageProfilers = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable language-specific profilers";
      };
      
      go = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Go profiling tools";
      };
      
      rust = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Rust profiling tools";
      };
      
      python = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Python profiling tools";
      };
      
      node = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Node.js profiling tools";
      };
      
      java = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Java profiling tools";
      };
    };
    
    debuggers = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable debugging tools";
      };
      
      gdb = mkOption {
        type = types.bool;
        default = true;
        description = "Enable GDB debugger";
      };
      
      lldb = mkOption {
        type = types.bool;
        default = true;
        description = "Enable LLDB debugger";
      };
      
      rr = mkOption {
        type = types.bool;
        default = isNixOS;
        description = "Enable rr record/replay debugger";
      };
    };
    
    tracers = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable tracing tools";
      };
      
      strace = mkOption {
        type = types.bool;
        default = isNixOS;
        description = "Enable strace system call tracer";
      };
      
      ltrace = mkOption {
        type = types.bool;
        default = isNixOS;
        description = "Enable ltrace library call tracer";
      };
    };
    
    memoryTools = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable memory analysis tools";
      };
      
      valgrind = mkOption {
        type = types.bool;
        default = isNixOS;
        description = "Enable Valgrind memory debugger";
      };
      
      heaptrack = mkOption {
        type = types.bool;
        default = isNixOS;
        description = "Enable Heaptrack heap profiler";
      };
      
      massif = mkOption {
        type = types.bool;
        default = isNixOS;
        description = "Enable Massif heap profiler";
      };
    };
    
    benchmarking = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable benchmarking tools";
      };
      
      hyperfine = mkOption {
        type = types.bool;
        default = true;
        description = "Enable hyperfine command-line benchmarking";
      };
      
      wrk = mkOption {
        type = types.bool;
        default = true;
        description = "Enable wrk HTTP benchmarking";
      };
      
      vegeta = mkOption {
        type = types.bool;
        default = true;
        description = "Enable vegeta load testing";
      };
    };
    
    visualization = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable performance visualization tools";
      };
      
      flamegraph = mkOption {
        type = types.bool;
        default = true;
        description = "Enable flamegraph generation";
      };
      
      hotspot = mkOption {
        type = types.bool;
        default = isNixOS;
        description = "Enable Hotspot perf GUI";
      };
    };
  };

  config = mkIf cfg.enable ({
    # Performance profiling and debugging packages
    environment.systemPackages = with pkgs; [
      # System profilers (Linux-only, in isNixOS section below)
      
      # Language-specific profilers
      (mkIf cfg.languageProfilers.go pprof)
      (mkIf cfg.languageProfilers.rust cargo-flamegraph)
      # (mkIf cfg.languageProfilers.rust cargo-profiling)  # Package not available
      (mkIf cfg.languageProfilers.python py-spy)
      (mkIf cfg.languageProfilers.python python311Packages.memory_profiler)
      (mkIf cfg.languageProfilers.python python311Packages.line_profiler)
      (mkIf cfg.languageProfilers.python python311Packages.snakeviz)
      # (mkIf cfg.languageProfilers.node nodePackages.clinic)  # Package not available
      # (mkIf cfg.languageProfilers.node nodePackages."0x")  # Package not available
      
      # Debuggers (cross-platform)
      (mkIf cfg.debuggers.lldb lldb)
      
      # Memory tools (Linux-only, in isNixOS section below)
      
      # Benchmarking tools
      (mkIf cfg.benchmarking.hyperfine hyperfine)
      (mkIf cfg.benchmarking.wrk wrk)
      (mkIf cfg.benchmarking.vegeta vegeta)
      httperf
      jmeter
      
      # Visualization tools
      (mkIf cfg.visualization.flamegraph flamegraph)
      
      # Additional profiling tools
      gperftools
      jemalloc
      mimalloc

      # System monitoring during profiling
      htop
      btop

      # Disk I/O profiling
      ioping
      fio

      # Network profiling
      iperf3
    ] ++ lib.optionals isNixOS [
      # Linux-only tools
      linuxPackages.perf
      bpftools
      bpftrace
      gdb
      rr
      strace
      ltrace
      lsof
      valgrind
      heaptrack
      hotspot
      kdePackages.kcachegrind
      iotop
      iftop
      nethogs
      sysstat
      dool
      cpupower-gui
      bonnie
      tcpdump
      wireshark-cli
      ngrep
      procps
      psmisc
      
      # Helper scripts
      (pkgs.writeShellScriptBin "profile-cpu" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        COMMAND="''${1:-}"
        DURATION="''${2:-30}"
        OUTPUT="''${3:-cpu-profile}"
        
        if [[ -z "$COMMAND" ]]; then
          echo "Usage: profile-cpu <command> [duration] [output-prefix]"
          exit 1
        fi
        
        echo "Profiling CPU usage for: $COMMAND"
        echo "Duration: $DURATION seconds"
        
        # Start the command in background
        $COMMAND &
        PID=$!
        
        # Profile based on platform
        if [[ "$(uname)" == "Linux" ]] && command -v perf >/dev/null 2>&1; then
          echo "Using Linux perf..."
          sudo perf record -F 99 -p $PID -g -- sleep $DURATION
          sudo perf report --stdio > "$OUTPUT.txt"
          
          # Generate flamegraph if available
          if command -v flamegraph.pl >/dev/null 2>&1; then
            sudo perf script | stackcollapse-perf.pl | flamegraph.pl > "$OUTPUT-flame.svg"
            echo "Flamegraph saved to: $OUTPUT-flame.svg"
          fi
        elif [[ "$(uname)" == "Darwin" ]]; then
          echo "Using macOS Instruments..."
          # Use dtrace or Instruments
          sudo sample $PID $DURATION -f "$OUTPUT.txt"
        fi
        
        # Kill the process if still running
        kill $PID 2>/dev/null || true
        
        echo "CPU profile saved to: $OUTPUT.txt"
      '')
      
      (pkgs.writeShellScriptBin "profile-memory" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        COMMAND="''${1:-}"
        OUTPUT="''${2:-memory-profile}"
        
        if [[ -z "$COMMAND" ]]; then
          echo "Usage: profile-memory <command> [output-prefix]"
          exit 1
        fi
        
        echo "Profiling memory usage for: $COMMAND"
        
        if command -v valgrind >/dev/null 2>&1; then
          echo "Using Valgrind Massif..."
          valgrind --tool=massif --massif-out-file="$OUTPUT.massif" $COMMAND
          ms_print "$OUTPUT.massif" > "$OUTPUT.txt"
          echo "Memory profile saved to: $OUTPUT.txt"
        elif command -v heaptrack >/dev/null 2>&1; then
          echo "Using Heaptrack..."
          heaptrack -o "$OUTPUT.heaptrack" $COMMAND
          heaptrack --analyze "$OUTPUT.heaptrack.gz" > "$OUTPUT.txt"
          echo "Memory profile saved to: $OUTPUT.txt"
        else
          echo "No suitable memory profiler found"
          echo "Falling back to time -v..."
          /usr/bin/time -v $COMMAND 2> "$OUTPUT.txt"
        fi
      '')
      
      (pkgs.writeShellScriptBin "profile-io" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        COMMAND="''${1:-}"
        DURATION="''${2:-30}"
        OUTPUT="''${3:-io-profile.txt}"
        
        if [[ -z "$COMMAND" ]]; then
          echo "Usage: profile-io <command> [duration] [output-file]"
          exit 1
        fi
        
        echo "Profiling I/O for: $COMMAND"
        echo "Duration: $DURATION seconds"
        
        # Start the command
        $COMMAND &
        PID=$!
        
        # Monitor I/O
        if command -v iotop >/dev/null 2>&1; then
          sudo iotop -b -p $PID -d 1 -n $DURATION > "$OUTPUT"
        elif command -v dool >/dev/null 2>&1; then
          dool -p $PID --disk --io --net 1 $DURATION > "$OUTPUT"
        else
          echo "No suitable I/O profiler found"
        fi
        
        # Kill the process if still running
        kill $PID 2>/dev/null || true
        
        echo "I/O profile saved to: $OUTPUT"
      '')
      
      (pkgs.writeShellScriptBin "benchmark-http" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        URL="''${1:-}"
        DURATION="''${2:-30s}"
        CONNECTIONS="''${3:-50}"
        OUTPUT="''${4:-http-benchmark}"
        
        if [[ -z "$URL" ]]; then
          echo "Usage: benchmark-http <url> [duration] [connections] [output-prefix]"
          exit 1
        fi
        
        echo "Benchmarking HTTP endpoint: $URL"
        echo "Duration: $DURATION, Connections: $CONNECTIONS"
        
        # Run multiple benchmarking tools
        if command -v wrk >/dev/null 2>&1; then
          echo "Running wrk..."
          wrk -t12 -c$CONNECTIONS -d$DURATION --latency "$URL" > "$OUTPUT-wrk.txt"
        fi
        
        if command -v vegeta >/dev/null 2>&1; then
          echo "Running vegeta..."
          echo "GET $URL" | vegeta attack -duration=$DURATION -rate=0 -max-workers=$CONNECTIONS | \
            vegeta report > "$OUTPUT-vegeta.txt"
          
          echo "GET $URL" | vegeta attack -duration=$DURATION -rate=0 -max-workers=$CONNECTIONS | \
            vegeta plot > "$OUTPUT-vegeta.html"
        fi
        
        if command -v ab >/dev/null 2>&1; then
          echo "Running Apache Bench..."
          ab -t ''${DURATION%s} -c $CONNECTIONS "$URL" > "$OUTPUT-ab.txt"
        fi
        
        echo "Benchmark results saved to: $OUTPUT-*.txt"
      '')
      
      # Debug helper script
      (pkgs.writeShellScriptBin "debug-process" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        PID="''${1:-}"
        
        if [[ -z "$PID" ]]; then
          echo "Usage: debug-process <pid>"
          exit 1
        fi
        
        echo "Debugging process: $PID"
        
        # Basic info
        echo "=== Process Info ==="
        ps -p $PID -o pid,ppid,user,%cpu,%mem,vsz,rss,tty,stat,start,time,comm
        
        # Open files
        echo -e "\n=== Open Files ==="
        lsof -p $PID 2>/dev/null | head -20
        
        # Network connections
        echo -e "\n=== Network Connections ==="
        lsof -i -a -p $PID 2>/dev/null || echo "No network connections"
        
        # Memory maps
        echo -e "\n=== Memory Maps (first 20 lines) ==="
        if [[ -r /proc/$PID/maps ]]; then
          head -20 /proc/$PID/maps
        fi
        
        # Stack trace
        echo -e "\n=== Stack Trace ==="
        if command -v gdb >/dev/null 2>&1; then
          echo -e "thread apply all bt\ndetach\nquit" | sudo gdb -p $PID 2>/dev/null | grep -A 20 "Thread"
        elif command -v lldb >/dev/null 2>&1; then
          echo -e "bt all\ndetach\nquit" | sudo lldb -p $PID 2>/dev/null
        fi
        
        echo -e "\nDebug information collected!"
      '')
    ];
    
    # Environment variables for profiling
    environment.variables = {
      # Enable debug symbols
      NIX_CFLAGS_COMPILE = "-g -O2";
      RUSTFLAGS = "-g";
      
      # Performance tool settings
      PERF_PAGER = "less";
    } // lib.optionalAttrs isNixOS {
      # Linux-specific
      DEBUGINFOD_URLS = "https://debuginfod.elfutils.org/";
    };
    
    # Shell aliases for profiling
    environment.shellAliases = {
      # CPU profiling
      prof-cpu = "profile-cpu";
      prof-flame = "perf record -F 99 -a -g";
      prof-top = "perf top -g";
      
      # Memory profiling
      prof-mem = "profile-memory";
      prof-heap = "heaptrack";
      prof-massif = "valgrind --tool=massif";
      prof-leak = "valgrind --leak-check=full";
      
      # I/O profiling
      prof-io = "profile-io";
      prof-disk = "iotop -b";
      prof-net = "iftop -t";
      
      # Benchmarking
      bench-cmd = "hyperfine";
      bench-http = "benchmark-http";
      bench-disk = "fio --name=test --size=1G --filename=test.dat --rw=randrw";
      
      # Debugging
      debug-pid = "debug-process";
      debug-core = "gdb -c";
      debug-attach = "gdb -p";
      
      # System monitoring
      mon-cpu = "htop -s PERCENT_CPU";
      mon-mem = "htop -s PERCENT_MEM";
      mon-io = "iotop";
      mon-net = "nethogs";
      
      # Tracing
      trace-sys = "strace -f -e trace=all";
      trace-file = "strace -f -e trace=file";
      trace-net = "strace -f -e trace=network";
      trace-mem = "strace -f -e trace=memory";
    };
    
  } // lib.optionalAttrs isNixOS {
    # Kernel parameters for better profiling
    boot = {
      kernel.sysctl = {
        # Allow perf for non-root users
        "kernel.perf_event_paranoid" = mkDefault 1;
        "kernel.kptr_restrict" = mkDefault 0;

        # Enable core dumps
        "kernel.core_uses_pid" = 1;
        "kernel.core_pattern" = "/tmp/core-%e-%p-%t";

        # Increase limits for profiling
        "fs.file-max" = 2097152;
        "vm.max_map_count" = 262144;
      };
    };
  });
}