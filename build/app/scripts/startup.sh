#!/usr/bin/env bash

## Run the commands to make it all work
ln -fs /usr/share/zoneinfo/$TZ /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata

echo $HOSTNAME > /etc/hostname

# Extract compressed binaries and move binaries to bin
if [ -e /opt/"$APPNAME"/scripts/.firstrun ]; then
    # Unzip frontail and tailon
    if [[ $(arch) == "x86_64" ]]; then
        gunzip /usr/local/bin/frontail.gz
    fi
    gunzip /usr/local/bin/tailon.gz

    # Copy python scripts to /usr/local/bin and make executable
    cp /opt/"$APPNAME"/scripts/ipcalc.py /usr/local/bin
    cp /opt/"$APPNAME"/scripts/ip-addrs-add /usr/local/bin
    cp /opt/"$APPNAME"/scripts/ip-routes-add /usr/local/bin
    cp /opt/"$APPNAME"/scripts/column.py /usr/local/bin
    cp /opt/"$APPNAME"/scripts/menu /usr/local/bin
    chmod 755 /usr/local/bin/ipcalc.py
    chmod 755 /usr/local/bin/ip-addrs-add
    chmod 755 /usr/local/bin/ip-routes-add
    chmod 755 /usr/local/bin/column.py
    chmod 775 /usr/local/bin/menu
fi

# Link scripts to debug folder as needed
if [ -e /opt/"$APPNAME"/scripts/.firstrun ]; then
    ln -s /opt/"$APPNAME"/scripts/tail.sh /opt/"$APPNAME"/debug
    ln -s /opt/"$APPNAME"/scripts/tmux.sh /opt/"$APPNAME"/debug
    ln -s /opt/"$APPNAME"/scripts/ipcalc.py /opt/"$APPNAME"/debug
    ln -s /opt/"$APPNAME"/scripts/ip-addrs-add /opt/"$APPNAME"/debug
    ln -s /opt/"$APPNAME"/scripts/ip-routes-add /opt/"$APPNAME"/debug
    ln -s /opt/"$APPNAME"/scripts/menu /opt/"$APPNAME"/debug
fi

# Create the file /var/run/utmp or when using tmux this error will be received
# utempter: pututline: No such file or directory
if [ -e /opt/"$APPNAME"/scripts/.firstrun ]; then
    touch /var/run/utmp
else
    truncate -s 0 /var/run/utmp
fi

# Link the log to the app log. Create/clear other log files.
if [ -e /opt/"$APPNAME"/scripts/.firstrun ]; then
    mkdir -p /opt/"$APPNAME"/logs
    touch /opt/"$APPNAME"/logs/"$APPNAME".log
else
    truncate -s 0 /opt/"$APPNAME"/logs/"$APPNAME".log
fi

# Print first message to either the app log file or syslog
echo "$(date -Is) [Start of $APPNAME log file]" >> /opt/"$APPNAME"/logs/"$APPNAME".log

# Check if `upload` subfolder exists. If non-existing, create it .
# Checking for a file inside the folder because if the folder
#  is mounted as a volume it will already exists when docker starts.
# Also change permissions
if [ ! -e "/opt/$APPNAME/upload/.exists" ]
then
    mkdir -p /opt/"$APPNAME"/upload
    touch /opt/"$APPNAME"/upload/.exists
    echo '`upload` folder created'
    cp /opt/"$APPNAME"/configs/addrs.csv /opt/"$APPNAME"/upload
    cp /opt/"$APPNAME"/configs/routes.csv /opt/"$APPNAME"/upload
    chown -R "${HUID}":"${HGID}" /opt/"$APPNAME"/upload
fi

# Modify configuration files or customize container
if [ -e /opt/"$APPNAME"/scripts/.firstrun ]; then
    # Commands to enable ip routing
    #  see current value
    # sysctl net.ipv4.ip_forward
    #  change it in config file
    # /etc/sysctl.conf 
    # net.ipv4.ip_forward=1
    #  change it in current boot
    # echo 1 > /proc/sys/net/ipv4/ip_forward
    # sysctl -w net.ipv4.ip_forward=1

    # These commands are not needed because docker enables ip routing
    # already, plus can't set inside the container.
    #echo 1 > /proc/sys/net/ipv4/ip_forward
    #sysctl -w net.ipv4.ip_forward=1
    sed -En '/net.ipv4.ip_forward/ s/^#([^#])/\1/p' /etc/sysctl.conf

    # Do not send hosts ICMP redirects
    sysctl -w net.ipv4.conf.lo.send_redirects=0
    sysctl -w net.ipv4.conf.eth0.send_redirects=0
    sysctl -w net.ipv4.conf.default.send_redirects=0
    sysctl -w net.ipv4.conf.all.send_redirects=0

    # Copy templates to configuration locations
    cp /opt/"$APPNAME"/configs/tmux.conf /root/.tmux.conf

    # Create menu.json
    /opt/"$APPNAME"/scripts/make_menujson.py /opt/"$APPNAME"/scripts/menu.json
fi

# Run the python script to add all the IPs and static routes
ip-addrs-add >> /opt/"$APPNAME"/logs/"$APPNAME".log
ip-routes-add >> /opt/"$APPNAME"/logs/"$APPNAME".log

# Start web interface
NLINES=1000 # how many tail lines to follow
sed -Ei 's/tail -n 500/tail -n '"$NLINES"'/' /opt/"$APPNAME"/scripts/tail.sh
sed -Ei 's/tail -n 500/tail -n '"$NLINES"'/' /opt/"$APPNAME"/scripts/tmux.sh
sed -Ei 's/\$lines/'"$NLINES"'/' /opt/"$APPNAME"/configs/tailon.toml
sed -Ei '/^listen-addr = /c listen-addr = [":'"$HTTPPORT4"'"]' /opt/"$APPNAME"/configs/tailon.toml

# ttyd1 (tail and read only)
nohup ttyd \
    --port "$HTTPPORT1" \
    --client-option titleFixed="${APPNAME}.log" \
    --client-option fontSize=16 \
    --client-option 'theme={"foreground":"black","background":"white","selectionBackground":"#ff6969"}' \
    --signal 2 \
    /opt/"$APPNAME"/scripts/tail.sh \
    >> /opt/"$APPNAME"/logs/ttyd1.log 2>&1 &

# ttyd2 (tmux and interactive)
nohup ttyd \
    --writable \
    --port "$HTTPPORT2" \
    --client-option titleFixed="${APPNAME}.log" \
    --client-option fontSize=16 \
    --client-option 'theme={"foreground":"black","background":"white","selectionBackground":"#ff6969"}' \
    --signal 9 \
    /opt/"$APPNAME"/scripts/tmux.sh \
    >> /opt/"$APPNAME"/logs/ttyd2.log 2>&1 &

# frontail
if [[ $(arch) == "x86_64" ]]; then
    nohup frontail \
        -n "$NLINES" \
        -p "$HTTPPORT3" \
        /opt/"$APPNAME"/logs/"$APPNAME".log \
        >> /opt/"$APPNAME"/logs/frontail.log 2>&1 &
fi

# tailon
nohup tailon \
    -c /opt/"$APPNAME"/configs/tailon.toml \
    /opt/"$APPNAME"/logs/"$APPNAME".log \
    /opt/"$APPNAME"/logs/ttyd1.log \
    /opt/"$APPNAME"/logs/ttyd2.log \
    /opt/"$APPNAME"/logs/frontail.log \
    /opt/"$APPNAME"/logs/tailon.log \
    >> /opt/"$APPNAME"/logs/tailon.log 2>&1 &

# Remove the .firstrun file if this is the first run
if [ -e /opt/"$APPNAME"/scripts/.firstrun ]; then
    rm -f /opt/"$APPNAME"/scripts/.firstrun
fi

# Keep docker running
bash
