#!/bin/bash
#SBATCH --job-name=gpu_job
#SBATCH --partition=gpu
#SBATCH --time=00:05:00
#SBATCH --nodes=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --gres=gpu:1
#SBATCH --output=gpu_%j.out
#SBATCH --error=gpu_%j.err

echo "=== GPU Job ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "GPUs on node: $SLURM_GPUS_ON_NODE"
echo "CUDA devices: $CUDA_VISIBLE_DEVICES"
echo "Start time: $(date)"

echo ""
echo "=== GPU Hardware ==="
nvidia-smi --query-gpu=name,driver_version,memory.total,memory.free,temperature.gpu,power.draw,pcie.link.gen.current,pcie.link.width.current --format=csv

echo ""
echo "=== GPU Utilization (5 samples, 1s interval) ==="
for i in $(seq 1 5); do
    util=$(nvidia-smi --query-gpu=utilization.gpu,utilization.memory,temperature.gpu,memory.used --format=csv,noheader)
    echo "  [$i] $util"
    sleep 1
done

echo ""
echo "=== GPU Processes ==="
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv 2>/dev/null || echo "No active compute processes"

echo ""
echo "End time: $(date)"
echo "=== Job Complete ==="
