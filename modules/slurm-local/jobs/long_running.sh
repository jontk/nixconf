#!/bin/bash
#SBATCH --job-name=long_running
#SBATCH --partition=all
#SBATCH --time=01:00:00
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=2G
#SBATCH --output=long_%j.out
#SBATCH --error=long_%j.err

echo "=== Long Running Job ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "Time limit: $SLURM_TIMELIMIT"
echo "Start time: $(date)"

echo ""
echo "=== Simulating long-running workload ==="
total=60
for i in $(seq 1 $total); do
    pct=$((i * 100 / total))
    bar=$(printf '%0.s#' $(seq 1 $((pct / 5))))
    printf "\r  Progress: [%-20s] %3d%% (%d/%d)" "$bar" "$pct" "$i" "$total"
    sleep 5
done
echo ""

echo ""
echo "End time: $(date)"
echo "=== Job Complete ==="
