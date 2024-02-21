#!/bin/bash

clear
# Setup styles for Gum commands
confirm_style='--prompt.foreground=44 --prompt.background=0 --prompt.border=double --prompt.height=3 --prompt.width=30 --prompt.bold --prompt.align=center --selected.background=44 --selected.foreground=0 --selected.height=1 --selected.width=20 --selected.align=center --unselected.background=0 --unselected.foreground=15 --unselected.height=1 --unselected.width=20 --unselected.align=center '

filter_style='--indicator=» --indicator.background=0 --indicator.foreground=44 --match.background=44 --match.foreground=0 --match.bold '

choose_style='--cursor=» --cursor.background=0 --cursor.foreground=44 --selected.background=44 --selected.foreground=0 --selected.bold '

input_style='--prompt.foreground=44 --prompt.bold --prompt.align=center --cursor.background=0 --cursor.foreground=44 --width=30 --cursor.border=double'

spin_style='--spinner=minidot --spinner.background=0 --spinner.foreground=44 --title.background=0 --title.foreground=44 ==title.border=rounded --title.align=center '

gum_style_error='--foreground=8 --background=235 --border=double --padding=1 --height=2'

# Function to check versions of required packages
check_versions() {
    GUM_VERSION=$(gum --version 2>/dev/null)
    JQ_VERSION=$(jq --version 2>/dev/null)
    AWS_VERSION=$(aws --version 2>&1 | head -n1) # aws --version writes to stderr

    MISSING_TOOLS=()

    [ -z "$GUM_VERSION" ] && MISSING_TOOLS+=("gum")
    [ -z "$JQ_VERSION" ] && MISSING_TOOLS+=("jq")
    [ -z "$AWS_VERSION" ] && MISSING_TOOLS+=("aws")
}

# Function to prompt for installation of missing packages
install_missing_packages() {
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "Detected that $tool is not installed."
        if [ "$tool" == "gum" ]; then
            # Fallback for confirmation without gum
            read -p "Would you like to install $tool? (y/n): " confirm
            [ "$confirm" != "${confirm#[Yy]}" ] && install_package "$tool"
        else
            # Use gum confirm if available
            if gum confirm $confirm_style --prompt "Would you like to install $tool?" --default=false --affirmative "[Yes]" --negative "[No]"; then
                install_package "$tool"
            fi
        fi
    done
}

# Function to install a given package
install_package() {
    case $1 in
        "gum")
            echo "Installing gum..."
            brew install gum #(for macOS)
            ;;
        "jq")
            echo "Installing jq..."
            brew install jq #(for macOS)
            ;;
        "aws")
            echo "Installing AWS CLI..."
            brew install awscli #(for macOS)
            ;;
        *)
            echo "No install command defined for $1"
            ;;
    esac
}

# Main script execution
check_versions
if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    install_missing_packages
else
    gum style --foreground 13 --background 235 "All required packages are installed."
fi

# Function to parse AWS profiles from credentials file
parse_aws_profiles() {
  grep '\[.*\]' ~/.aws/credentials | sed 's/\[\(.*\)\]/\1/'
}

# Function to parse SSH keys from ~/.ssh
parse_ssh_keys() {
  ls ~/.ssh | grep -E "\.pub$" | sed 's/\.pub$//'
}

get_ec2_id_filter() {
  EC2_NAMES=$(aws ec2 describe-instances --region "$SELECTED_REGION" --profile "$AWS_PROFILE" --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value' --output text)
  
  # Check if EC2_NAMES is empty, indicating no instances were found
  if [ -z "$EC2_NAMES" ]; then
    gum style $gum_style_error "No EC2 instances available in the selected region. Exiting script..."
    exit 1
  fi

  EC2_NAME=$(echo "$EC2_NAMES" | gum filter $filter_style --limit 1 --header="Instance Name:")
  if [ -z "$EC2_NAME" ]; then
    gum style $gum_style_error "No instance selected. Exiting..."
    exit 1
  fi

  EC2_ID=$(aws ec2 describe-instances --region "$SELECTED_REGION" --profile "$AWS_PROFILE" --query 'Reservations[].Instances[?Tags[?Key==`Name` && Value==`'"$EC2_NAME"'`]].InstanceId' --output text)
  if [ -z "$EC2_ID" ]; then
    gum style $gum_style_error "Failed to retrieve the instance ID. Exiting script..."
    exit 1
  fi
}

get_ec2_id_choose() {
  EC2_NAMES=$(aws ec2 describe-instances --region "$SELECTED_REGION" --profile "$AWS_PROFILE" --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value' --output text)
  # Check if EC2_NAMES is empty, indicating no instances were found
  if [ -z "$EC2_NAMES" ]; then
    gum style $gum_style_error "No EC2 instances available in the selected region. Exiting script..."
    exit 1
  fi

  EC2_NAME=$(echo "$EC2_NAMES" | gum choose $choose_style --header="Available Instances:")
  if [ -z "$EC2_NAME" ]; then
    gum style $gum_style_error "No instance selected. Exiting..."
    exit 1
  fi
  EC2_ID=$(aws ec2 describe-instances --region $SELECTED_REGION --profile $AWS_PROFILE | jq -r '.Reservations[].Instances[] | select(.Tags[].Value == "'$EC2_NAME'") | .InstanceId')
  if [ -z "$EC2_ID" ]; then
    gum style $gum_style_error "Failed to retrieve the instance ID. Exiting script..."
    exit 1
  fi      
}

ec2_connect() {
  aws ssm start-session \
   --color on \
   --target $EC2_ID \
   --profile $AWS_PROFILE
}

ec2_send_command() {
  ESCAPED_SSH_KEY_CONTENT=$(printf '%s\n' "$SSH_KEY_CONTENT" | sed 's/"/\\"/g; s/`/\\`/g')

  CHECK_AND_ADD_KEY_COMMAND="touch /home/ssm-user/.ssh/authorized_keys && if grep -Fxq \\\"$ESCAPED_SSH_KEY_CONTENT\\\" /home/ssm-user/.ssh/authorized_keys; then echo 'SSH key already exists. No changes made.'; else mkdir -p /home/ssm-user/.ssh && echo \\\"$ESCAPED_SSH_KEY_CONTENT\\\" >> /home/ssm-user/.ssh/authorized_keys && echo 'SSH key added successfully.'; fi"

  COMMAND_OUTPUT=$(aws ssm send-command --profile "$AWS_PROFILE" --instance-ids "$EC2_ID" \
    --document-name "AWS-RunShellScript" \
    --comment "Copy SSH key" \
    --output json \
    --parameters "commands=[\"$CHECK_AND_ADD_KEY_COMMAND\"]" 2>&1)

  COMMAND_ID=$(echo "$COMMAND_OUTPUT" | jq -r '.Command.CommandId' 2>/dev/null)

  if [ -z "$COMMAND_ID" ]; then
    gum style --foreground 8 --background 235 --border double --padding "1" --margin "1 2" --height 2 "Failed to send command. AWS CLI Output: $COMMAND_OUTPUT"
    return 1
  fi

  gum style --foreground 13 --background 235 "Command sent successfully, awaiting execution result..."

  while true; do
    RESULT=$(aws ssm list-command-invocations --command-id "$COMMAND_ID" --details --profile "$AWS_PROFILE" --output json)
    STATUS=$(echo "$RESULT" | jq -r '.CommandInvocations[0].Status')

    if [[ "$STATUS" == "Success" ]]; then
      # Fetch the output of the command execution
      OUTPUT=$(echo "$RESULT" | jq -r '.CommandInvocations[0].CommandPlugins[0].Output')
      clear
      gum style --foreground 10 --background 235 --border double --padding "1" --margin "1 2" --height 2 "$OUTPUT"
      break
    elif [[ "$STATUS" == "Failed" || "$STATUS" == "Cancelled" || "$STATUS" == "TimedOut" ]]; then
      clear
      gum style --foreground 8 --background 235 --border double --padding "1" --margin "1 2" --height 2 "Command execution finished with status $STATUS."
      break
    fi
    sleep 5
  done
}



# Helper function to wait for a file to exist
wait_for_file() {
    while [[ ! -f "$1" ]]; do sleep 1; done
}

direct_port_forward() {
  aws ssm start-session \
    --target $EC2_ID \
    --profile $AWS_PROFILE \
    --document-name AWS-StartPortForwardingSession \
    --parameters '{"portNumber":[$REMOTE_PORT],"localPortNumber":[$LOCAL_PORT]}'
}

remote_port_forward() {
  aws ssm start-session \
    --target $EC2_ID \
    --profile $AWS_PROFILE \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters '{"host":$DB_ENDPOINT,"localPortNumber":[$LOCAL_PORT],"portNumber":[$REMOTE_PORT]}'
}

## Set the terminal title and style
gum style --foreground 44 --background 0 --border double --padding "1" --margin "1 2" --bold --height 2 --underline "SSM Connect Script"


# Choose AWS profile
AWS_PROFILE=$(parse_aws_profiles | gum choose $choose_style --header="Choose an AWS Profile")
AWS_REGIONS=$(aws ec2 describe-regions --profile $AWS_PROFILE | jq -r '.Regions[].RegionName')
SELECTED_REGION=$(gum filter $filter_style --limit 1 --header="Choose a region:" <<< "$AWS_REGIONS")

# Main menu using gum choose
ACTION=$(gum choose $choose_style "Connect to EC2" "Port Forward to EC2 (direct)" "Port Forward to Database" "Copy SSH key to EC2" "Exit" --header="What would you like to do?")

case $ACTION in
  "Connect to EC2")
    LISTEC2=$(gum choose $choose_style "List EC2's" "Enter EC2 Name" "Cancel" --header="How would you like to specify the EC2 instance?")
    case $LISTEC2 in
      "List EC2's")
        get_ec2_id_choose
        gum spin $spin_style --title "Connecting..." --
        ec2_connect
        ;;
      "Enter EC2 Name")
        get_ec2_id_filter
        ec2_connect
        ;;
      "Exit")
        echo "Exiting script..."
        exit 0
        ;;
    esac
    ;;
  "Port Forward to EC2 (direct)")
    EC2_NAME=$(gum input $input_style --placeholder "EC2 Instance Name")
    LOCAL_PORT=$(gum input $input_style --placeholder "Local Port")
    REMOTE_PORT=$(gum input $input_style --placeholder "Remote Port")
    gum spin $spin_style --title "Connecting..." -- sleep 3
    direct_port_forward
    ;;
  "Port Forward to Database")
    DB_ENDPOINT=$(gum input $input_style --placeholder "Database Endpoint")
    EC2_NAME=$(gum input $input_style --placeholder "EC2 Instance Name for Port Forward")
    LOCAL_PORT=$(gum input $input_style --placeholder "Local Port")
    REMOTE_PORT=$(gum input $input_style --placeholder "Remote Port")
    gum spin $spin_style --title "Connecting..." -- sleep 3
    remote_port_forward
    ;;
  "Copy SSH key to EC2")
    SSH_KEY_FILE=$(ls ~/.ssh/*.pub | gum choose $choose_style)

    if [ -z "$SSH_KEY_FILE" ]; then
        echo "No file selected. Exiting..."
        exit 1
    fi

    SSH_KEY_CONTENT=$(cat "$SSH_KEY_FILE")
    if [ $? -ne 0 ]; then
        echo "Error reading the SSH key file. Exiting..."
        exit 1
    fi

    get_ec2_id_filter 

    ESCAPED_SSH_KEY_CONTENT=$(echo "$SSH_KEY_CONTENT" | sed 's/"/\\"/g')

    COMMANDS="mkdir -p /home/ssm-user/.ssh && touch /home/ssm-user/.ssh/authorized_keys && chmod 600 /home/ssm-user/.ssh/authorized_keys && chown -R ssm-user /home/ssm-user/.ssh && echo '$ESCAPED_SSH_KEY_CONTENT' >> /home/ssm-user/.ssh/authorized_keys"
    gum confirm $confirm_style "Copy SSH Key to $EC2_NAME?" --default=false --affirmative "[Yes]" --negative "[No]" && ec2_send_command "$COMMANDS"
    ;;
esac