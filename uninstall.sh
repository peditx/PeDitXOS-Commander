#!/bin/sh

echo ">>> Starting a complete cleanup of LuCI Commander..."

# Stop and disable the ttyd service if it exists
if [ -f /etc/init.d/luci_commander_ttyd ]; then
    echo "Stopping and disabling luci_commander_ttyd service..."
    /etc/init.d/luci_commander_ttyd stop >/dev/null 2>&1
    /etc/init.d/luci_commander_ttyd disable >/dev/null 2>&1
fi

# Remove all related files
echo "Removing application files..."
rm -f /usr/lib/lua/luci/controller/commander.lua
rm -f /usr/lib/lua/luci/view/commander.htm
rm -f /usr/bin/commander_runner.sh
rm -f /etc/init.d/luci_commander_ttyd

# Clean up temporary files and logs
echo "Removing temporary files and logs..."
rm -f /tmp/commander_log.txt
rm -f /tmp/commander.lock
rm -f /tmp/installer_script.sh

# Re-start uhttpd to clear the old menu
echo "Restarting uhttpd service to finalize cleanup..."
/etc/init.d/uhttpd restart >/dev/null 2>&1

echo "Cleanup complete. All LuCI Commander files and services have been removed."
