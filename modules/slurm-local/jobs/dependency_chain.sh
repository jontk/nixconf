#!/bin/bash
# Submit a chain of dependent jobs
# Usage: bash dependency_chain.sh

echo "=== Submitting Dependency Chain ==="

JOB1=$(sbatch --parsable --partition=normal --job-name=stage1-extract --time=00:02:00 --mem=1G \
    --wrap='echo "Stage 1: Data extraction"; sleep 10; echo "Extraction complete"')
echo "Stage 1 (extract): Job $JOB1"

JOB2=$(sbatch --parsable --partition=normal --job-name=stage2-transform --time=00:02:00 --mem=1G \
    --dependency=afterok:$JOB1 \
    --wrap='echo "Stage 2: Data transformation"; sleep 8; echo "Transform complete"')
echo "Stage 2 (transform): Job $JOB2 (depends on $JOB1)"

JOB3=$(sbatch --parsable --partition=gpu --gres=gpu:1 --job-name=stage3-train --time=00:03:00 --mem=2G \
    --dependency=afterok:$JOB2 \
    --wrap='echo "Stage 3: Model training on GPU $CUDA_VISIBLE_DEVICES"; nvidia-smi -L; sleep 15; echo "Training complete"')
echo "Stage 3 (train): Job $JOB3 (depends on $JOB2)"

JOB4=$(sbatch --parsable --partition=normal --job-name=stage4-evaluate --time=00:02:00 --mem=1G \
    --dependency=afterok:$JOB3 \
    --wrap='echo "Stage 4: Model evaluation"; sleep 5; echo "Accuracy: 94.2%"; echo "Evaluation complete"')
echo "Stage 4 (evaluate): Job $JOB4 (depends on $JOB3)"

echo ""
echo "=== Job Chain Submitted ==="
echo "Pipeline: extract($JOB1) -> transform($JOB2) -> train($JOB3) -> evaluate($JOB4)"
echo ""
squeue -l
