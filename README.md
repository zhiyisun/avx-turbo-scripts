# AVX-Turbo Scripts

Scripts for downloading, building, and benchmarking the [avx-turbo](https://github.com/travisdowns/avx-turbo) project to analyze CPU frequency scaling behavior with AVX instructions.

## Overview

This repository contains scripts that automate the process of:
1. Downloading and building the AVX-Turbo project
2. Running various benchmark tests with different core allocations
3. Collecting and organizing test results

These scripts are designed to work on any Linux system and will automatically detect the CPU configuration of the host machine.

## Scripts

### avx-turbo-setup.sh

Downloads and builds the AVX-Turbo project.

```bash
./avx-turbo-setup.sh
```

Features:
- Clones the AVX-Turbo repository from GitHub
- Updates the repository if it already exists
- Builds the project using make

### avx-turbo-benchmark.sh

Runs a series of benchmarks with various core configurations and saves results to log files.

```bash
./avx-turbo-benchmark.sh
```

Features:
- Automatically detects the number of CPU cores per socket and number of sockets
- Runs a default benchmark test
- Tests various combinations of scalar and AVX512 instructions across cores:
  - Per-socket tests: Tests all combinations within a single socket
  - Server-wide tests: Tests combinations across all sockets (only on multi-socket systems)
- Saves all test results to timestamped log files for analysis

## Benchmark Configuration

The benchmarks specifically test combinations of:
- `scalar_iadd`: Integer addition operations using scalar instructions
- `avx512_iadd`: Integer addition operations using AVX-512 instructions

The script creates various combinations where:
- The total number of cores equals the number of physical cores per socket (for per-socket tests)
- The total number of cores equals the total physical cores across all sockets (for server-wide tests)

## Log Files

All benchmark results are saved in the `benchmark_logs` directory with the following naming conventions:

- Default test: `avx_turbo_default_TIMESTAMP.log`
- Per-socket tests: `avx_turbo_sX_aY_TIMESTAMP.log` (where X = scalar cores, Y = AVX512 cores)
- Server-wide tests: `avx_turbo_server_sX_aY_TIMESTAMP.log` (where X = scalar cores, Y = AVX512 cores)

Each set of tests includes a timestamp to prevent overwriting previous results.

## Requirements

- Linux-based OS
- ZSH shell (or modify the shebang line for your preferred shell)
- Git
- Make and a C++ compiler (to build the AVX-Turbo project)
- sudo access (required to run the AVX-Turbo benchmarks)

## Created On

May 20, 2025