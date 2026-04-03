#!/bin/bash
#SBATCH --job-name=array_task
#SBATCH --partition=normal
#SBATCH --time=00:02:00
#SBATCH --nodes=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=512M
#SBATCH --array=1-5
#SBATCH --output=array_%A_%a.out
#SBATCH --error=array_%A_%a.err

echo "=== Array Job ==="
echo "Array Job ID: $SLURM_ARRAY_JOB_ID"
echo "Array Task ID: $SLURM_ARRAY_TASK_ID"
echo "Node: $SLURM_NODELIST"
echo "Start time: $(date)"

echo ""
echo "=== Processing task $SLURM_ARRAY_TASK_ID ==="

# Simulate different work per task
case $SLURM_ARRAY_TASK_ID in
    1) echo "Task 1: Data ingestion";  sleep 5;;
    2) echo "Task 2: Preprocessing";   sleep 8;;
    3) echo "Task 3: Feature extract"; sleep 6;;
    4) echo "Task 4: Validation";      sleep 4;;
    5) echo "Task 5: Report gen";      sleep 3;;
esac

echo "Task $SLURM_ARRAY_TASK_ID completed successfully"
echo "End time: $(date)"
echo "=== Task Complete ==="
