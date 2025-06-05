#!/bin/bash

# Script to run AVX-Turbo benchmarks with various configurations
# Created on: May 20, 2025

# Note: We don't use 'set -e' here because we want to continue even if individual tests fail
# Individual test failures are handled gracefully within the script

sudo cpupower frequency-set -r -g performance
sudo cpupower idle-set -d 2

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

# Run the default test with retry logic for aborted commands
max_retries=5
retry_count=0
command_success=false

while [ ${retry_count} -lt ${max_retries} ] && [ "${command_success}" = false ]; do
    echo "Default test attempt $((retry_count + 1))/${max_retries}..."
    
    # Run the command and capture exit status
    if sudo ./avx-turbo > "${DEFAULT_LOG}" 2>&1; then
        # Command executed without error, now check if output is valid
        if grep -q "A/M-MHz" "${DEFAULT_LOG}"; then
            command_success=true
            echo "Default test completed successfully with valid output."
        else
            echo "Default test completed but log file does not contain 'A/M-MHz'. Retrying..."
            retry_count=$((retry_count + 1))
            sleep 2
        fi
    else
        # Command failed or was aborted
        exit_code=$?
        echo "Default test failed with exit code ${exit_code} (possibly aborted). Retrying..."
        
        # Check if the log file contains any abort-related messages
        if [ -f "${DEFAULT_LOG}" ]; then
            if grep -qi "abort\|segmentation\|killed\|terminated" "${DEFAULT_LOG}"; then
                echo "Detected abort/crash in default test log file. Cleaning up and retrying..."
            fi
        fi
        
        retry_count=$((retry_count + 1))
        sleep 3  # Longer sleep after failure
    fi
done

# Final check if all retries failed
if [ "${command_success}" = false ]; then
    echo "ERROR: Failed to complete default test after ${max_retries} attempts."
    echo "Last log file content:"
    if [ -f "${DEFAULT_LOG}" ]; then
        tail -10 "${DEFAULT_LOG}"
    fi
    echo "Exiting script due to default test failure."
    exit 1
fi

# Function to run benchmark with specified core allocations
run_benchmark() {
    local scalar_cores=$1
    local avx512_cores=$2
    local test_type=${3:-"socket"}  # Default to "socket" if not specified
    
    local spec_arg="scalar_iadd/${scalar_cores},avx512_iadd/${avx512_cores}"
    local log_file
    
    # Set log file name based on test type
    if [ "${test_type}" = "server" ]; then
        log_file="${LOG_DIR}/avx_turbo_server_s${scalar_cores}_a${avx512_cores}_${TIMESTAMP}.log"
        echo "Running server-wide test with ${scalar_cores} scalar cores, ${avx512_cores} AVX512 cores"
    else
        log_file="${LOG_DIR}/avx_turbo_s${scalar_cores}_a${avx512_cores}_${TIMESTAMP}.log"
        echo "Running socket-level test with ${scalar_cores} scalar cores, ${avx512_cores} AVX512 cores"
    fi
    
    echo "Test spec: ${spec_arg}"
    echo "Results will be saved to: ${log_file}"
    
    cd "${REPO_DIR}"
    
    # Run the benchmark with retry logic for aborted commands
    local max_retries=5
    local retry_count=0
    local command_success=false
    
    while [ ${retry_count} -lt ${max_retries} ] && [ "${command_success}" = false ]; do
        echo "Attempt $((retry_count + 1))/${max_retries} for ${test_type} test..."
        
        # Run the command and capture exit status
        if sudo ./avx-turbo --spec=${spec_arg} --warmup-ms=1000 > "${log_file}" 2>&1; then
            # Command executed without error, now check if output is valid
            if grep -q "A/M-MHz" "${log_file}"; then
                command_success=true
                echo "Command completed successfully with valid output."
            else
                echo "Command completed but log file does not contain 'A/M-MHz'. Retrying..."
                retry_count=$((retry_count + 1))
                sleep 2
            fi
        else
            # Command failed or was aborted
            local exit_code=$?
            echo "Command failed with exit code ${exit_code} (possibly aborted). Retrying..."
            
            # Check if the log file contains any abort-related messages
            if [ -f "${log_file}" ]; then
                if grep -qi "abort\|segmentation\|killed\|terminated" "${log_file}"; then
                    echo "Detected abort/crash in log file. Cleaning up and retrying..."
                fi
            fi
            
            retry_count=$((retry_count + 1))
            sleep 3  # Longer sleep after failure
        fi
    done
    
    # Final check if all retries failed
    if [ "${command_success}" = false ]; then
        echo "ERROR: Failed to complete ${test_type} test after ${max_retries} attempts."
        echo "Last log file content:"
        if [ -f "${log_file}" ]; then
            tail -10 "${log_file}"
        fi
        return 1
    fi
    
    echo "Completed ${test_type} test with ${scalar_cores} scalar cores, ${avx512_cores} AVX512 cores"
}

# Run benchmarks with different core combinations
echo "Running socket-level benchmarks with different core combinations..."

# Run all different combinations of scalar_iadd and avx512_iadd cores (socket-level)
for scalar_cores in $(seq 1 ${CORES_PER_SOCKET}); do
    avx512_cores=$((CORES_PER_SOCKET - scalar_cores))
    
    # Only run if avx512_cores is positive
    if [ ${avx512_cores} -ge 0 ]; then
        if ! run_benchmark ${scalar_cores} ${avx512_cores} "socket"; then
            echo "WARNING: Socket-level test with ${scalar_cores} scalar cores and ${avx512_cores} AVX512 cores failed after multiple retries. Continuing with next test..."
        fi
    fi
done

# Additional test using all physical cores across sockets (only if multiple sockets are present)
if [ "${SOCKETS}" -gt 1 ]; then
    echo "Running server-wide benchmarks with all physical cores across all sockets..."

    # Calculate total physical cores across all sockets
    TOTAL_PHYSICAL_CORES=$((CORES_PER_SOCKET * SOCKETS))
    echo "Total physical cores across all sockets: ${TOTAL_PHYSICAL_CORES}"

    # Run tests with different combinations using all physical cores (server-level)
    for scalar_cores in $(seq 1 $((TOTAL_PHYSICAL_CORES - 1))); do
        avx512_cores=$((TOTAL_PHYSICAL_CORES - scalar_cores))
        
        # Only run if avx512_cores is positive
        if [ ${avx512_cores} -gt 0 ]; then
            if ! run_benchmark ${scalar_cores} ${avx512_cores} "server"; then
                echo "WARNING: Server-level test with ${scalar_cores} scalar cores and ${avx512_cores} AVX512 cores failed after multiple retries. Continuing with next test..."
            fi
        fi
    done
else
    echo "Single socket detected. Skipping server-wide tests."
fi

echo "All benchmarks completed. Results are saved in ${LOG_DIR} directory."
echo "Summary of tests:"
ls -lh "${LOG_DIR}" | grep "${TIMESTAMP}"
