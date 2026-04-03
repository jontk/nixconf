#!/bin/bash
#SBATCH --job-name=basic_job
#SBATCH --partition=normal
#SBATCH --time=00:05:00
#SBATCH --nodes=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --output=basic_%j.out
#SBATCH --error=basic_%j.err

echo "=== Basic Job ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "CPUs: $SLURM_CPUS_ON_NODE"
echo "Working directory: $(pwd)"
echo "Start time: $(date)"

echo ""
echo "=== System Info ==="
uname -a
echo "CPUs available: $(nproc)"
free -h | head -2

echo ""
echo "=== Running workload ==="
for i in $(seq 1 5); do
    echo "Step $i/5 - $(date +%H:%M:%S)"
    sleep 3
done

echo ""
echo "End time: $(date)"
echo "=== Job Complete ==="
