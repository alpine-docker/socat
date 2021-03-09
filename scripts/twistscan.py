#!/usr/bin/env python3

import argparse
import importlib
import json
import os
import platform
import re
import subprocess
import sys


###
# GLOBALS
###

TWISTCLI_PATH           = '%s/bin/twistcli' % os.getenv('HOME')
TWISTLOCK_CONSOLE       = 'https://twistlock.tools.mspenv.io'
TWISTCLI_DOWNLOAD_LINUX = 'api/v1/util/twistcli'
TWISTCLI_DOWNLOAD_MACOS = 'api/v1/util/osx/twistcli'


###
# MAIN METHOD
###

def main():
    # Check env
    creds = check_credentials()

    # Check args
    args = check_args()

    # Ensure docker image is available
    check_pull_docker(args.image)

    # Check for twistcli
    check_install_twistcli(creds)

    # Run scan
    output_file = run_twistcli(args.image, creds)

    # Check results
    process_results(args.image, output_file, args.critical_only)

    # Finished
    print(' * twistlock scan complete.')
    print()


# Process cli args
def check_args():
    # Prepare args
    script_name = sys.argv[0]

    # Setup parser
    parser = argparse.ArgumentParser(description='example: %s -i alpine:latest' % script_name)

    # Example using str with default
    parser.add_argument('-i', required=True, help='docker image name, eg. "alpine:latest"', dest='image')

    # Example using bool
    parser.add_argument('-c', required=False, help='critical vulnerabilities only', action='store_true', dest='critical_only')

    return parser.parse_args()


# Pull docker image if not present
def check_pull_docker(image):
    # Dynamically install docker package if required
    docker = package_hack('docker')

    # Create docker client
    client = docker.from_env()

    # Check for image
    try:
        client.images.get(image)
        print(' * image present on system: %s' % image)

    except docker.errors.ImageNotFound:
        print(' * image not found. Pulling image: %s ...' % image)
        client.images.pull(image)


# Fetch twistcli if not found
def check_install_twistcli(creds):
    # First check for twistcli
    if not os.path.isfile(TWISTCLI_PATH):
        download_twistcli(creds)

    print(' * twistcli command located: %s' % TWISTCLI_PATH)


# Download twistcli from console
def download_twistcli(creds):
    print(' * downloading twistcli to path: %s ...' % TWISTCLI_PATH)

    # Build url based on platform detection
    if platform.system() == 'Darwin':
        url = f'{TWISTLOCK_CONSOLE}/{TWISTCLI_DOWNLOAD_MACOS}'
    else:
        url = f'{TWISTLOCK_CONSOLE}/{TWISTCLI_DOWNLOAD_LINUX}'

    print(' * download url: %s' % url)

    # Create download command using curl
    twist_user = creds['user']
    twist_pass = creds['pass']

    cmd = f'''curl -k -L -s \\
                -u {twist_user}:{twist_pass} \\
                -o {TWISTCLI_PATH} {url}'''

    # Execute command
    p = subprocess.Popen(cmd, shell=True)
    p.communicate()

    # Ensure twistcli is executable
    os.chmod(TWISTCLI_PATH, 0o755)


# Execute twistcli via shell
def run_twistcli(image, creds):
    print(' * executing twistcli ...')
    # Determine file name for json output
    output_file = generate_output_filename(image)

    # Build twistcli command
    twist_user = creds['user']
    twist_pass = creds['pass']

    cmd = f'''{TWISTCLI_PATH} images scan \\
            -u {twist_user} \\
            -p {twist_pass} \\
            --details \\
            --address {TWISTLOCK_CONSOLE} \\
            --output-file {output_file} \\
            {image}'''

    # Execute command
    p = subprocess.Popen(cmd, shell=True)
    p.communicate()
    print()

    # Return file name
    return output_file


# Create output file based on image name
def generate_output_filename(image):
    # Remove unfriendly characters
    file_name = re.sub(r'[:\/\.]+', '_', image)

    return f'/tmp/{file_name}.json'


# Expect twistlock user/pass env vars
def check_credentials():
    twistlock_user = check_env('TWISTLOCK_USER')
    twistlock_pass = check_env('TWISTLOCK_PASS')

    return {'user': twistlock_user, 'pass': twistlock_pass}


# Process results and check for vulnerabilities
def process_results(image, output_file, critical_only):
    # Read json file
    with open(output_file) as f:
        results = json.load(f)
        vuln_dist = results['results'][0]['vulnerabilityDistribution']

        # Note: only vulnerability levels checked
        vuln_crit = vuln_dist['critical']
        vuln_high = vuln_dist['high']

        # Display report
        display_report(image, vuln_crit, vuln_high)

        if vuln_crit > 0:
            fatal('error: critical vulnerabilities detected: %s' % vuln_crit)

        if not critical_only:
            if vuln_high > 0:
                fatal('error: high vulnerabilities detected: %s' % vuln_high)


# Show text output of results
def display_report(image, vuln_crit, vuln_high):
    logline()
    logmsg('                   VULNERABILITY SCAN RESULTS')
    logmsg(' ')
    logmsg('  IMAGE: %s' % image)
    logmsg('    -> %s critical' % vuln_crit)
    logmsg('    -> %s high' % vuln_high)
    logmsg(' ')
    logline()
    print()



def logline():
    print(' ********************************************************************** ')


def logmsg(msg):
    print(' * %-66s *' % msg)


# Check for exiting env vars
def check_env(field, strict=True):
    val = os.getenv(field)

    if not val and strict:
        fatal('error: env var not found: %s' % field)

    return val


# Log message and exit
def fatal(msg):
    print(msg)
    print('Aborting.')
    sys.exit(1)


# Check and install missing packages
def package_hack(package_name):
    mod = None
    try:
        mod = importlib.import_module(package_name)
    except ModuleNotFoundError:
        p = subprocess.Popen(f'pip3 install --user {package_name}', shell=True)
        p.communicate()

        # Refresh cache
        importlib.invalidate_caches()
        mod = importlib.import_module(package_name)

    return mod



####
# MAIN
####

# Invoke main method
if __name__ == '__main__':
    main()
