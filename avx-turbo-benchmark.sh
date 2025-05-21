#!/bin/bash

# Script to run AVX-Turbo benchmarks with various configurations
# Created on: May 20, 2025

set -e  # Exit immediately if a command exits with a non-zero status

# Define working directory and repository directory
WORK_DIR=$(pwd)
REPO_DIR="${WORK_DIR}/avx-turbo"
LOG_DIR="${WORK_DIR}/benchmark_logs"

# Check if avx-turbo exists
if [ ! -f "${REPO_DIR}/avx-turbo" ]; then
    echo "Error: avx-turbo executable not found at ${REPO_DIR}/avx-turbo"
    echo "Please run avx-turbo-setup.sh first to download and build the project."
    exit 1
fi

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Get timestamp for log files
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Get CPU information - detect cores per socket
echo "Detecting CPU information..."
CORES_PER_SOCKET=$(lscpu | grep "Core(s) per socket" | awk '{print $4}')
SOCKETS=$(lscpu | grep "Socket(s)" | awk '{print $2}')

echo "Found ${CORES_PER_SOCKET} cores per socket, ${SOCKETS} socket(s)"
TOTAL_CORES=$((CORES_PER_SOCKET * SOCKETS))

# First, run the default test
echo "Running default test..."
DEFAULT_LOG="${LOG_DIR}/avx_turbo_default_${TIMESTAMP}.log"
echo "Default test results will be saved to: ${DEFAULT_LOG}"
cd "${REPO_DIR}"
sudo ./avx-turbo --warmup-ms=1000 > "${DEFAULT_LOG}" 2>&1
echo "Default test completed."

# Function to run benchmark with specified core allocations
run_benchmark() {
    local scalar_cores=$1
    local avx512_cores=$2
    
    local spec_arg="scalar_iadd/${scalar_cores},avx512_iadd/${avx512_cores}"
    local log_file="${LOG_DIR}/avx_turbo_s${scalar_cores}_a${avx512_cores}_${TIMESTAMP}.log"
    
    echo "Running test with spec=${spec_arg}"
    echo "Results will be saved to: ${log_file}"
    
    cd "${REPO_DIR}"
    sudo ./avx-turbo --spec=${spec_arg} --warmup-ms=1000 > "${log_file}" 2>&1
    sleep 1
    
    echo "Completed test with ${scalar_cores} scalar cores, ${avx512_cores} AVX512 cores"
}

# Run benchmarks with different core combinations
echo "Running benchmarks with different core combinations..."

# Run all different combinations of scalar_iadd and avx512_iadd cores
for scalar_cores in $(seq 1 ${CORES_PER_SOCKET}); do
    avx512_cores=$((CORES_PER_SOCKET - scalar_cores))
    
    # Only run if avx512_cores is positive
    if [ ${avx512_cores} -ge 0 ]; then
        run_benchmark ${scalar_cores} ${avx512_cores}
    fi
done

# Additional test using all physical cores across sockets (only if multiple sockets are present)
if [ "${SOCKETS}" -gt 1 ]; then
    echo "Running additional test with all physical cores across all sockets..."

    # Calculate total physical cores across all sockets
    TOTAL_PHYSICAL_CORES=$((CORES_PER_SOCKET * SOCKETS))
    echo "Total physical cores across all sockets: ${TOTAL_PHYSICAL_CORES}"

    # Run tests with different combinations using all physical cores
for scalar_cores in $(seq 1 $((TOTAL_PHYSICAL_CORES - 1))); do
    avx512_cores=$((TOTAL_PHYSICAL_CORES - scalar_cores))
    
    # Only run if avx512_cores is positive
    if [ ${avx512_cores} -gt 0 ]; then
        # Create a distinct log name for server-wide tests
        log_file="${LOG_DIR}/avx_turbo_server_s${scalar_cores}_a${avx512_cores}_${TIMESTAMP}.log"
        
        echo "Running server-wide test with ${scalar_cores} scalar cores, ${avx512_cores} AVX512 cores"
        echo "Results will be saved to: ${log_file}"
        
        cd "${REPO_DIR}"
        sudo ./avx-turbo --spec=scalar_iadd/${scalar_cores},avx512_iadd/${avx512_cores} --warmup-ms=1000 > "${log_file}" 2>&1
        sleep 1
        echo "Completed server-wide test with ${scalar_cores} scalar cores, ${avx512_cores} AVX512 cores"
    fi
done
else
    echo "Single socket detected. Skipping server-wide tests."
fi

echo "All benchmarks completed. Results are saved in ${LOG_DIR} directory."
echo "Summary of tests:"
ls -lh "${LOG_DIR}" | grep "${TIMESTAMP}"
