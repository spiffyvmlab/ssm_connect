# SSM Connect Script

This script simplifies managing AWS EC2 instances through AWS Systems Manager (SSM), allowing for easy connection, port forwarding, and SSH key management.

## Features

- Connect to EC2 instances using SSM.
- Direct port forwarding to EC2 instances.
- Port forwarding to databases through EC2 instances.
- Copy SSH keys to EC2 instances.

## Prerequisites

- AWS CLI installed and configured.
- `jq` for parsing JSON responses.
- `gum` for interactive prompts and styling. [Gum on Github](https://github.com/charmbracelet/gum)

## Installation

The script will check for the above prerequisites and install them if they are not found. At the moment, it's only designed to do so on MacOS, via `brew` but you can easily modify the script to work with other package managers.

## This Repo

Currently, this repo only contains a bash script. I plan to rewrite this script in Python and Go, to make it more portable and cross-platform.

## Contributing

If you have any ideas for features, or find any bugs, please feel free to open an issue. I'm always looking for ways to improve the script.

If you'd like to help with a Go or Python version, please let me know.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.