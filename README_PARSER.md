# AVX Turbo Log Parser

This script parses AVX Turbo log files and generates CSV reports for analysis.

## Features

1. Parses `avx_turbo_default*.log` files into multiple CSV files, one per instruction ID, with columns:
   - Cores
   - ID
   - Description
   - Mops (average)
   - A/M-MHz (average)

2. Parses `avx_turbo_s*.log` files into a single CSV file with columns:
   - Cores
   - ID
   - Description
   - S Value
   - A Value
   - A/M-MHz (average)

3. Parses `avx_turbo_server_s*.log` files into a similar CSV file with the same columns.

## Usage

Basic usage:

```bash
python parse_logs.py
```

This will read log files from the `./emr` directory by default and output CSV files to the `./csv_results` directory.

### Command-line Options

- `--input_dir`: Directory containing the log files (default: `./emr`)
- `--output_dir`: Directory to store the CSV files (default: `./csv_results`)
- `--additional_dir`: Optional additional directory containing log files to process
- `--additional_output_dir`: Output directory for additional logs (default: `<output_dir>_<additional_dir_name>`)

### Examples

Process logs from the default directory:

```bash
python parse_logs.py
```

Process logs from a specific directory:

```bash
python parse_logs.py --input_dir=/path/to/logs --output_dir=output_csv
```

Process logs from two different directories:

```bash
python parse_logs.py --input_dir=./emr --additional_dir=./9825_performance
```

## Output

The script generates:

1. For default logs: One CSV file per instruction ID (e.g., `default_avx128_fma.csv`, `default_scalar_iadd.csv`, etc.)
2. For s* logs: A single CSV file with all data (`all_s_cases.csv`)
3. For server_s* logs: A single CSV file with all data (`all_server_s_cases.csv`)

## Requirements

- Python 3.6 or later
- Standard Python libraries (no external dependencies required)
