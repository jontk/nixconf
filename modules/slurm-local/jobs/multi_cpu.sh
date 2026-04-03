#!/bin/bash
#SBATCH --job-name=multi_cpu
#SBATCH --partition=normal
#SBATCH --time=00:05:00
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --output=multi_cpu_%j.out
#SBATCH --error=multi_cpu_%j.err

echo "=== Multi-CPU Job ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "CPUs allocated: $SLURM_CPUS_PER_TASK"
echo "Start time: $(date)"

echo ""
echo "=== Parallel Workload (${SLURM_CPUS_PER_TASK} workers) ==="

run_worker() {
    local id=$1
    echo "  Worker $id started at $(date +%H:%M:%S)"
    # Simulate CPU work
    local count=0
    for i in $(seq 1 1000000); do
        count=$((count + 1))
    done
    echo "  Worker $id finished at $(date +%H:%M:%S) (counted to $count)"
}

for w in $(seq 1 ${SLURM_CPUS_PER_TASK:-4}); do
    run_worker $w &
done
wait

echo ""
echo "All workers complete"
echo "End time: $(date)"
echo "=== Job Complete ==="
