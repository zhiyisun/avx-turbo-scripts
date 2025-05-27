#!/usr/bin/env python3
"""
AVX Turbo Log Parser

This script parses AVX Turbo log files and generates CSV reports for analysis.

See README_PARSER.md for more information.
"""

import os
import re
import csv
import glob
import statistics
import argparse
from collections import defaultdict

def parse_default_logs(log_dir, output_dir):
    """Parse default log files and create one CSV per instruction ID."""
    print("Processing default logs...")
    
    # Dictionary to store data for each instruction ID
    instruction_data = defaultdict(lambda: defaultdict(list))
    
    # Find all default log files
    default_logs = glob.glob(os.path.join(log_dir, "avx_turbo_default_*.log"))
    
    for log_file in default_logs:
        print(f"  Processing {os.path.basename(log_file)}")
        
        with open(log_file, 'r') as f:
            lines = f.readlines()
            
            # Process the relevant lines
            for line in lines:
                # Skip header lines and empty lines
                if not line.strip() or line.startswith('//') or line.startswith('CPUID') or \
                   line.startswith('Running') or line.startswith('MSR') or \
                   line.startswith('CPU') or line.startswith('cpuid') or \
                   line.startswith('tsc_freq') or line.startswith('available') or \
                   line.startswith('physical') or line.startswith('Will test'):
                    continue
                
                # Skip lines with headers for the next core count
                if re.match(r'^Cores \| ID', line):
                    continue
                
                # Skip header lines
                if 'Cores | ID' in line:
                    continue
                    
                # Process the data lines
                parts = line.strip().split('|')
                if len(parts) >= 5:
                    try:
                        cores = int(parts[0].strip())
                    except ValueError:
                        # Skip lines that don't start with a number
                        continue
                        
                    instr_id = parts[1].strip()
                    description = parts[2].strip()
                    
                    # Get Mops values (part 4)
                    try:
                        mops_str = parts[4].strip()
                        mops_values = [float(x.strip()) for x in mops_str.split(',') if x.strip()]
                    except ValueError:
                        # Skip invalid values
                        continue
                    
                    # Get A/M-MHz values (part 6)
                    try:
                        am_mhz_str = parts[6].strip() if len(parts) >= 7 else "0" 
                        am_mhz_values = [float(x.strip()) for x in am_mhz_str.split(',') if x.strip()]
                    except ValueError:
                        # Skip invalid values
                        continue
                    
                    # Calculate averages
                    avg_mops = statistics.mean(mops_values) if mops_values else 0
                    avg_am_mhz = statistics.mean(am_mhz_values) if am_mhz_values else 0
                    
                    # Store the data
                    instruction_data[instr_id][cores].append({
                        'Cores': cores,
                        'ID': instr_id,
                        'Description': description,
                        'Mops': avg_mops,
                        'A/M-MHz': avg_am_mhz
                    })
    
    # Write CSV files for each instruction ID
    os.makedirs(output_dir, exist_ok=True)
    
    for instr_id, cores_data in instruction_data.items():
        safe_id = instr_id.replace('/', '_').replace(' ', '_')
        csv_file = os.path.join(output_dir, f"default_{safe_id}.csv")
        
        with open(csv_file, 'w', newline='') as csvfile:
            fieldnames = ['Cores', 'ID', 'Description', 'Mops', 'A/M-MHz']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            
            # Write data for each core count
            for cores in sorted(cores_data.keys()):
                for entry in cores_data[cores]:
                    writer.writerow(entry)
    
    print(f"Default logs processed. CSV files written to {output_dir}")

def parse_s_logs(log_dir, output_dir):
    """Parse s* log files and create one CSV for all s* cases."""
    print("Processing s* logs...")
    
    # Dictionary to store data for all s* cases
    s_data = []
    
    # Find all s* log files (not server_s*)
    s_logs = glob.glob(os.path.join(log_dir, "avx_turbo_s[0-9]*_a[0-9]*.log"))
    
    for log_file in s_logs:
        if 'server_s' in log_file:
            continue  # Skip server logs, they'll be processed separately
            
        print(f"  Processing {os.path.basename(log_file)}")
        
        with open(log_file, 'r') as f:
            lines = f.readlines()
            
            # Process the relevant lines
            for line in lines:
                # Skip header lines and empty lines
                if not line.strip() or line.startswith('//') or line.startswith('CPUID') or \
                   line.startswith('Running') or line.startswith('MSR') or \
                   line.startswith('CPU') or line.startswith('cpuid') or \
                   line.startswith('tsc_freq') or line.startswith('available') or \
                   line.startswith('physical') or line.startswith('Will test'):
                    continue
                
                # Skip header lines
                if 'Cores | ID' in line:
                    continue
                
                # Extract s and a values from filename
                s_match = re.search(r'avx_turbo_s(\d+)_a(\d+)', os.path.basename(log_file))
                if s_match:
                    s_value = int(s_match.group(1))
                    a_value = int(s_match.group(2))
                else:
                    continue
                
                # Process the data lines
                parts = line.strip().split('|')
                if len(parts) >= 5:
                    try:
                        cores = int(parts[0].strip())
                    except ValueError:
                        # Skip lines that don't start with a number
                        continue
                        
                    instr_id = parts[1].strip()
                    description = parts[2].strip()
                    
                    # Get A/M-MHz values (column 6)
                    try:
                        am_mhz_str = parts[6].strip() if len(parts) >= 7 else "0"
                        am_mhz_values = [float(x.strip()) for x in am_mhz_str.split(',') if x.strip()]
                    except ValueError:
                        # Skip invalid values
                        continue
                    
                    # Calculate average
                    avg_am_mhz = statistics.mean(am_mhz_values) if am_mhz_values else 0
                    
                    # Store the data (without Description column)
                    s_data.append({
                        'Cores': cores,
                        'ID': instr_id,
                        'S Value': s_value,
                        'A Value': a_value,
                        'A/M-MHz': avg_am_mhz
                    })
    
    # Write CSV file for all s* cases
    os.makedirs(output_dir, exist_ok=True)
    csv_file = os.path.join(output_dir, "all_s_cases.csv")
    
    with open(csv_file, 'w', newline='') as csvfile:
        fieldnames = ['Cores', 'ID', 'S Value', 'A Value', 'A/M-MHz']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        
        # Sort by cores, s value, a value, and ID for better readability
        s_data.sort(key=lambda x: (x['Cores'], x['S Value'], x['A Value'], x['ID']))
        
        # Write all data
        for entry in s_data:
            writer.writerow(entry)
    
    print(f"S* logs processed. CSV file written to {csv_file}")

def parse_server_s_logs(log_dir, output_dir):
    """Parse server_s* log files and create one CSV for all server_s* cases."""
    print("Processing server_s* logs...")
    
    # Dictionary to store data for all server_s* cases
    server_s_data = []
    
    # Find all server_s* log files
    server_s_logs = glob.glob(os.path.join(log_dir, "avx_turbo_server_s[0-9]*_a[0-9]*.log"))
    
    for log_file in server_s_logs:
        print(f"  Processing {os.path.basename(log_file)}")
        
        with open(log_file, 'r') as f:
            lines = f.readlines()
            
            # Process the relevant lines
            for line in lines:
                # Skip header lines and empty lines
                if not line.strip() or line.startswith('//') or line.startswith('CPUID') or \
                   line.startswith('Running') or line.startswith('MSR') or \
                   line.startswith('CPU') or line.startswith('cpuid') or \
                   line.startswith('tsc_freq') or line.startswith('available') or \
                   line.startswith('physical') or line.startswith('Will test'):
                    continue
                    
                # Skip header lines
                if 'Cores | ID' in line:
                    continue
                
                # Extract s and a values from filename
                s_match = re.search(r'avx_turbo_server_s(\d+)_a(\d+)', os.path.basename(log_file))
                if s_match:
                    s_value = int(s_match.group(1))
                    a_value = int(s_match.group(2))
                else:
                    continue
                
                # Process the data lines
                parts = line.strip().split('|')
                if len(parts) >= 5:
                    try:
                        cores = int(parts[0].strip())
                    except ValueError:
                        # Skip lines that don't start with a number
                        continue
                        
                    instr_id = parts[1].strip()
                    description = parts[2].strip()
                    
                    # Get A/M-MHz values (column 6)
                    try:
                        am_mhz_str = parts[6].strip() if len(parts) >= 7 else "0"
                        am_mhz_values = [float(x.strip()) for x in am_mhz_str.split(',') if x.strip()]
                    except ValueError:
                        # Skip invalid values
                        continue
                    
                    # Calculate average
                    avg_am_mhz = statistics.mean(am_mhz_values) if am_mhz_values else 0
                    
                    # Store the data (without Description column)
                    server_s_data.append({
                        'Cores': cores,
                        'ID': instr_id,
                        'S Value': s_value,
                        'A Value': a_value,
                        'A/M-MHz': avg_am_mhz
                    })
    
    # Write CSV file for all server_s* cases
    os.makedirs(output_dir, exist_ok=True)
    csv_file = os.path.join(output_dir, "all_server_s_cases.csv")
    
    with open(csv_file, 'w', newline='') as csvfile:
        fieldnames = ['Cores', 'ID', 'S Value', 'A Value', 'A/M-MHz']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        
        # Sort by cores, s value, a value, and ID for better readability
        server_s_data.sort(key=lambda x: (x['Cores'], x['S Value'], x['A Value'], x['ID']))
        
        # Write all data
        for entry in server_s_data:
            writer.writerow(entry)
    
    print(f"Server s* logs processed. CSV file written to {csv_file}")

def main():
    parser = argparse.ArgumentParser(description='Parse AVX Turbo log files and generate CSV reports.')
    parser.add_argument('--input_dir', default='./emr', 
                        help='Directory containing the log files (default: ./emr)')
    parser.add_argument('--output_dir', default='./csv_results', 
                        help='Directory to store the CSV files (default: ./csv_results)')
    parser.add_argument('--additional_dir', default=None,
                        help='Additional directory containing log files to process (e.g., 9825_performance)')
    parser.add_argument('--additional_output_dir', default=None,
                        help='Output directory for additional logs (default: <output_dir>_<additional_dir_name>)')
    
    args = parser.parse_args()
    
    print(f"Input directory: {args.input_dir}")
    print(f"Output directory: {args.output_dir}")
    
    # Check if input directory exists
    if not os.path.exists(args.input_dir):
        print(f"ERROR: Input directory {args.input_dir} does not exist!")
        return
    
    # Create output directory if it doesn't exist
    os.makedirs(args.output_dir, exist_ok=True)
    print(f"Created output directory: {args.output_dir}")
    
    # Process each type of log file
    try:
        parse_default_logs(args.input_dir, args.output_dir)
        parse_s_logs(args.input_dir, args.output_dir)
        parse_server_s_logs(args.input_dir, args.output_dir)
        print("All log files processed successfully.")
    except Exception as e:
        print(f"ERROR: {e}")
        
    # Process additional directory if specified
    if args.additional_dir and os.path.exists(args.additional_dir):
        print(f"\nProcessing additional directory: {args.additional_dir}")
        
        # Determine output directory for additional files
        additional_output_dir = args.additional_output_dir
        if not additional_output_dir:
            dir_name = os.path.basename(args.additional_dir.rstrip('/\\'))
            additional_output_dir = f"{args.output_dir}_{dir_name}"
        
        os.makedirs(additional_output_dir, exist_ok=True)
        print(f"Created additional output directory: {additional_output_dir}")
        
        try:
            parse_default_logs(args.additional_dir, additional_output_dir)
            parse_s_logs(args.additional_dir, additional_output_dir)
            parse_server_s_logs(args.additional_dir, additional_output_dir)
            print(f"All log files in {args.additional_dir} processed successfully.")
        except Exception as e:
            print(f"ERROR processing {args.additional_dir}: {e}")

if __name__ == "__main__":
    main()
