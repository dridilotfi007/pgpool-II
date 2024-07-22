#!/bin/bash

POSTGRESQL_STARTUP_USER=postgres
SSH_KEY_FILE=id_rsa_pgpool
SSH_OPTIONS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa_pgpool'
SSH_TIMEOUT=5
PGPOOLS=(192.168.56.101 192.168.56.102)
VIP=192.168.56.150
DEVICE=enp0s9

echo "Starting escalation.sh script"

for pgpool in "${PGPOOLS[@]}"
do
    if [ "$(hostname -I | grep -o "$pgpool")" != "$pgpool" ]; then
        echo "Attempting to release VIP on $pgpool"
        RELEASE_VIP_CMD="if ip addr show $DEVICE | grep -q $VIP; then
                            sudo ip addr del $VIP/24 dev $DEVICE
                            if [ $? -eq 0 ]; then
                                echo 'Successfully released VIP $VIP on $DEVICE'
                            else
                                echo 'Failed to release VIP $VIP on $DEVICE'
                            fi
                        else
                            echo 'VIP $VIP not found on $DEVICE, skipping deletion.'
                        fi"
        timeout $SSH_TIMEOUT ssh -T $SSH_OPTIONS $POSTGRESQL_STARTUP_USER@$pgpool "$RELEASE_VIP_CMD"
        if [ $? -ne 0 ]; then
            echo "ERROR: escalation.sh: failed to release VIP on $pgpool."
        else
            echo "Successfully released VIP on $pgpool."
        fi
    fi
done

echo "Assigning VIP to local interface"
if ip addr show $DEVICE | grep -q $VIP; then
    echo "VIP $VIP is already assigned to $DEVICE."
else
    sudo ip addr add $VIP/24 dev $DEVICE
    if [ $? -eq 0 ]; then
        echo "Successfully assigned VIP $VIP to $DEVICE."
    else
        echo "ERROR: Failed to assign VIP $VIP to $DEVICE."
        exit 1
    fi
fi

exit 0
