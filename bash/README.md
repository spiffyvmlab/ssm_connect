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

## Usage

To run the script, simply cd into the directory and run `./ssm.sh`. The script will guide you through the process.
Alternately, you can map the script to an alias in your `.bashrc` or `.zshrc` file, to make it executeable from anywhere on the system. (Recommended)

On each run, the script will ask you to first select your AWS Profile, and then your AWS Region.
- The profile is the name of the profile in your `~/.aws/credentials` file.
- The region is the AWS region where your EC2 instances are located. The script will give a searchable list of all available regions in your account.

## Options

- Connect to an EC2 instance.
    - List all EC2 instances.
        - Lists all EC2 instances in the current region. Use up and down arrow keys to navigate and enter to select. No search functionality.
    - Name an EC2 instance to connect to.
        - Generates a searchable list of all EC2 instances. Use up and down arrow keys to navigate and enter to select.
- Forward a port to an EC2 instance. (WIP)
    - Create a port forward to the instance, to access a service that is running on that instance via a port on your local machine.
- Forward a port to a database through an EC2 instance. (WIP)
    - Create a port forward to the instance, to access a database that is running on another instance or managed service (RDS), via a port on your local machine. 
- Copy SSH keys to an EC2 instance.
    - Copies the selected SSH key to the selected EC2 instance.
    - This is useful if you need to use SSH to connect to the instance directly for things like VSCode's Remote SSH extension, or SCP for moving files to and from the instance.
        - This will require setting up a ProxyCommand in your SSH config file, to use the SSM Session Manager to connect to the instance. The script does not do this for you at the moment. 

## Other things to note

Don't like the color scheme, or it doesn't work well because you're one of those people who likes to use a light terminal theme? You can easily change the colors in the script. Just look for the `*_style` variables towards the top of the script and change the color codes to your liking.

## Contributing

If you have any ideas for features, or find any bugs, please feel free to open an issue. I'm always looking for ways to improve the script.

Ideally, I'll be rewriting this script in Python and Go, to make it more portable, and cross-platform. But for now, it's just a simple bash script. If you'd like to help with a Go or Python version, please let me know.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.