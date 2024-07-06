#!/bin/bash

# function to display a message and exit
function show_error() {
    whiptail --title "Error" --msgbox "$1" 8 45
    exit 1
}

# get host id (ip address or hostname)
HOST_ID=$(whiptail --inputbox "Enter Host ID (IP address or hostname):" 8 45 3>&1 1>&2 2>&3)
[ $? -eq 0 ] || show_error "Host ID is required."

# get remote username
REMOTE_USERNAME=$(whiptail --inputbox "Enter Remote Username:" 8 45 3>&1 1>&2 2>&3)
[ $? -eq 0 ] || show_error "Remote Username is required."

# check if the host is reachable
ping -c 1 $HOST_ID &> /dev/null
if [ $? -ne 0 ]; then
    show_error "Host $HOST_ID is unreachable."
fi

# get host password
HOST_PASSWORD=$(whiptail --passwordbox "Enter Host Password:" 8 45 3>&1 1>&2 2>&3)
[ $? -eq 0 ] || show_error "Host Password is required."

# select transfer mode
TRANSFER_MODE=$(whiptail --menu "Choose Transfer Mode" 15 45 3 \
    "1" "Archive" \
    "2" "Zip" \
    "3" "Direct" 3>&1 1>&2 2>&3)
[ $? -eq 0 ] || show_error "Transfer Mode is required."

# get local file/directory to transfer using zenity file selection dialog
LOCAL_FILE=$(zenity --file-selection --title="Select File/Directory to Transfer")
if [ $? -ne 0 ]; then
    show_error "File selection is required."
fi
[ -e "$LOCAL_FILE" ] || show_error "Local file/directory not found."

# set up transfer command based on selected mode
case $TRANSFER_MODE in
    1) 
        TRANSFER_CMD="rsync -avz -e 'ssh' $LOCAL_FILE $REMOTE_USERNAME@$HOST_ID:/home/$REMOTE_USERNAME/Desktop"
        ;;
    2)
        ZIP_FILE="/tmp/transfer.zip"
        zip -r $ZIP_FILE $LOCAL_FILE
        TRANSFER_CMD="rsync -avz -e 'ssh' $ZIP_FILE $REMOTE_USERNAME@$HOST_ID:/home/$REMOTE_USERNAME/Desktop && rm $ZIP_FILE"
        ;;
    3)
        TRANSFER_CMD="rsync -avz -e 'ssh' $LOCAL_FILE $REMOTE_USERNAME@$HOST_ID:/home/$REMOTE_USERNAME/Desktop"
        ;;
    *)
        show_error "Invalid Transfer Mode."
        ;;
esac

# perform the file transfer with progress shown in the same tab
(
    echo 0
    echo "# Starting transfer..."
    sshpass -p "$HOST_PASSWORD" $TRANSFER_CMD 2>&1 | while read -r line; do
        echo "# $line"
        sleep 0.1
    done
    echo 100
) | whiptail --gauge "File Transfer Progress" 6 60 0

if [ $? -eq 0 ]; then
    whiptail --title "Success" --msgbox "File transfer completed successfully." 8 45
else
    show_error "File transfer failed."
fi

exit 0
