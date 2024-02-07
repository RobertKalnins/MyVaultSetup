#!/bin/bash

# Load Unseal Keys and server address variable
source /etc/vault.d/vault-unseal.env

# Function to check the status of Vault
check_vault_status() {
    local status=$(vault status 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "Vault status check failed. Retrying in 2 seconds..."
        sleep 2
        return 1
    fi
    if echo "$status" | grep -q "^Sealed\s*true$"; then
        echo "Vault is sealed."
        return 2
    elif echo "$status" | grep -q "^Sealed\s*false$"; then
        echo "Vault is unsealed. Exiting successfully."
        return 0
    else
        echo "Unable to determine Vault status. Retrying in 2 seconds..."
        sleep 2
        return 1
    fi
}

# Function to attempt to unseal Vault.
attempt_unseal() {
	curl --request PUT --data '{"key": "'"$VAULT_UNSEAL_KEY_1"'"}' $VAULT_ADDR/v1/sys/unseal
	curl --request PUT --data '{"key": "'"$VAULT_UNSEAL_KEY_2"'"}' $VAULT_ADDR/v1/sys/unseal
	curl --request PUT --data '{"key": "'"$VAULT_UNSEAL_KEY_3"'"}' $VAULT_ADDR/v1/sys/unseal
}

# Counter for loop iterations
counter=0
# Wait for Vault to be unsealed, with a maximum of 5 attempts
while (( counter < 5 )); do
    check_vault_status
    status=$?  # Capture the return value of check_vault_status
    echo "Status: $status"
    case $status in
        0)  # Vault is unsealed
            echo "Vault is unsealed."
            exit 0 ;;
        1)  # Unable to determine status or error occurred
            echo "Unable to determine status or error occurred."
            ((counter++))
            sleep 2  # Add delay before retrying
            continue ;;
        2)  # Vault is sealed
            echo "Vault is sealed. Attempting to unseal Vault..."
            attempt_unseal
            ((counter++))
            sleep 2  # Add delay before retrying
            ;;
        *)  # Handle unexpected or empty status
            echo "Unknown status: $status"
            ((counter++))
            continue ;;
    esac
done

echo "Failed to unseal Vault after 5 attempts."
exit 1