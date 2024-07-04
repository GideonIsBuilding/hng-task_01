#!/bin/bash

#--------------------------
# Function to echo in green
#--------------------------
green_echo() {
    echo -e "\e[32m$1\e[0m"
}

#------------------------
# Function to echo in red
#------------------------
red_echo() {
    echo -e "\e[31m$1\e[0m"
}

#---------------------------------------------------------
# Check if a file path argument is provided and validate it
#---------------------------------------------------------
if [ -z "$1" ]; then
    red_echo "Error: No file path provided. Please provide the employee config file path as the first argument."
    exit 1
fi

EMPLOYEE_CONFIG_FILE="$1"

if [ ! -f "$EMPLOYEE_CONFIG_FILE" ]; then
    red_echo "Error: The file '$EMPLOYEE_CONFIG_FILE' does not exist or is not a regular file."
    exit 1
fi

green_echo "File path is valid."

#-----------------------------------------
# Variables for the password and log files
#-----------------------------------------
PASSWORD_FILE="/var/secure/user_passwords.txt"
LOG_FILE="/var/log/user_management.log"

#----------------------------------------------------------
# Create necessary directories with appropriate permissions
#----------------------------------------------------------
sudo mkdir -p /var/secure
sudo mkdir -p /var/log
sudo chmod 600 /var/secure

#----------------------------------------------
# Checking and ensuring makepasswd is installed
#----------------------------------------------
if ! command -v makepasswd &>/dev/null; then
    sudo apt-get update && sudo apt-get install -y makepasswd
fi

#---------------------------------------
# Generate a random password of 16 xters
#---------------------------------------
generate_password() {
    makepasswd --chars 16
}

#--------------------------------------
# Clear previous log and password files
#--------------------------------------
sudo truncate -s 0 "$LOG_FILE"
sudo truncate -s 0 "$PASSWORD_FILE"

while IFS=';' read -r username groups; do

    #----------------------------------------
    # Remove leading and trailing whitespaces
    #----------------------------------------
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    #-----------------
    # Skip empty lines
    #-----------------
    [ -z "$username" ] && continue

    #---------------------------------
    # Split the groups field by commas
    #---------------------------------
    IFS=',' read -ra group_array <<<"$groups"

    #---------------------------------
    # Check if the user already exists
    #---------------------------------
    if id "$username" &>/dev/null; then
        red_echo "The user $username already exists." | sudo tee -a "$LOG_FILE"
    else
        sudo useradd -m -s /bin/bash "$username" &&
            green_echo "The user $username has been created." | sudo tee -a "$LOG_FILE"

        #---------------------------
        # Generate a random password
        #---------------------------
        password=$(generate_password)

        #------------------------
        # Set the user's password
        #------------------------
        echo "$username:$password" | sudo chpasswd
        echo "$username:$password" | sudo tee -a "$PASSWORD_FILE"
    fi

    #--------------------------------------------------------
    # Create a primary group for the user if it doesn't exist
    #--------------------------------------------------------
    if ! getent group "$username" >/dev/null; then
        sudo groupadd "$username" &&
            green_echo "Primary group $username created." | sudo tee -a "$LOG_FILE"
    fi

    for group in "${group_array[@]}"; do
        if ! getent group "$group" >/dev/null; then
            sudo groupadd "$group" &&
                green_echo "Group $group created." | sudo tee -a "$LOG_FILE"
        fi
        sudo usermod -aG "$group" "$username" &&
            green_echo "User $username added to group $group." | sudo tee -a "$LOG_FILE"
    done

    #-------------------------------
    # Set home directory permissions
    #-------------------------------
    sudo chown -R "$username":"$username" "/home/$username"
    sudo chmod 700 "/home/$username"

done <"$EMPLOYEE_CONFIG_FILE"

green_echo "User onboarding script completed. See $LOG_FILE for details."
