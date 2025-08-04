#!/bin/sh

#================================================================
# LuCI Commander Installer Script (v45 - Final)
#================================================================
# This version updates the styling of the tab buttons to match
# the "Analyze" and "Start Installation" buttons for a unified UI.
#================================================================

# --- Cleanup ---
echo ">>> Cleaning up old versions..."
rm -f /usr/lib/lua/luci/controller/commander.lua
rm -f /usr/lib/lua/luci/view/commander.htm
rm -f /usr/bin/commander_runner.sh
if [ -f /etc/init.d/luci_commander_ttyd ]; then
    /etc/init.d/luci_commander_ttyd stop >/dev/null 2>&1
    /etc/init.d/luci_commander_ttyd disable >/dev/null 2>&1
    rm -f /etc/init.d/luci_commander_ttyd
fi
echo "Cleanup complete."

# --- Dependency Installation ---
echo ">>> Installing dependencies (ttyd)..."
opkg update
opkg install ttyd
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install ttyd."
    exit 1
fi

# --- LuCI File Creation ---
echo ">>> Creating LuCI application files..."
mkdir -p /usr/lib/lua/luci/controller /usr/lib/lua/luci/view

# Create LuCI Controller
cat > /usr/lib/lua/luci/controller/commander.lua <<'EoL'
module("luci.controller.commander", package.seeall)

function index()
    -- This logic creates the parent menu if it doesn't exist,
    -- exactly like the user's successful sshplus script.
    entry({"admin", "peditxos"}, firstchild(), "PeDitXOS Tools", 50).dependent=true
    
    -- Adding the child menu item for the Commander
    entry({"admin", "peditxos", "commander"}, template("commander"), "Commander", 30).dependent = true
    
    -- API endpoints for the Smart Installer
    entry({"admin", "peditxos", "commander_analyze"}, call("analyze_script")).json = true
    entry({"admin", "peditxos", "commander_run"}, call("run_script")).json = true
    entry({"admin", "peditxos", "commander_log"}, call("get_log")).json = true
    entry({"admin", "peditxos", "commander_history"}, call("get_history")).json = true
    entry({"admin", "peditxos", "commander_clear_history"}, call("clear_history")).json = true
end

function analyze_script()
    local url = luci.http.formvalue("url")
    if not url or url == "" then
        luci.http.prepare_content("application/json")
        luci.http.write_json({success = false, error = "URL cannot be empty"})
        return
    end
    
    local result = luci.sys.exec("/usr/bin/commander_runner.sh analyze \"" .. url .. "\"")
    luci.http.prepare_content("application/json")
    luci.http.write(result)
end

function get_log()
    local log_file = "/tmp/commander_log.txt"
    local content = ""
    local f = io.open(log_file, "r")
    if f then
        content = f:read("*a")
        f:close()
    end
    luci.http.prepare_content("application/json")
    luci.http.write_json({ log = content })
end

function get_history()
    local history_file = "/etc/luci-commander-history.json"
    local history = {}
    local file = io.open(history_file, "r")
    if file then
        for line in file:lines() do
            local status, result = pcall(luci.json.decode, line)
            if status then
                table.insert(history, result)
            end
        end
        file:close()
    end
    luci.http.prepare_content("application/json")
    luci.http.write_json({ history = history })
end

function clear_history()
    local history_file = "/etc/luci-commander-history.json"
    luci.sys.exec("rm -f " .. history_file)
    luci.http.prepare_content("application/json")
    luci.http.write_json({ success = true })
end

function run_script()
    local url = luci.http.formvalue("url")
    local params = luci.http.formvalue("params")
    
    if not url or url == "" then
        luci.http.prepare_content("application/json")
        luci.http.write_json({success = false, error = "URL is missing"})
        return
    end
    
    -- Write to history file before execution
    local history_file = "/etc/luci-commander-history.json"
    local history_entry = { url = url, params = params }
    local history_json = luci.json.encode(history_entry)
    luci.sys.exec("echo '" .. history_json .. "' >> " .. history_file)
    
    luci.sys.exec("nohup /usr/bin/commander_runner.sh execute \"" .. url .. "\" '" .. params .. "' >/dev/null 2>&1 &")
    
    luci.http.prepare_content("application/json")
    luci.http.write_json({success = true})
end
EoL

# Create LuCI View (Tabbed UI)
cat > /usr/lib/lua/luci/view/commander.htm <<'EoL'
<%+header%>

<style>
    :root {
        --peditx-primary: #ffc107; /* New vibrant yellow/orange */
        --peditx-dark-bg: #2d2d2d;
        --peditx-card-bg: #3a3a3a;
        --peditx-border: #444;
        --peditx-text-color: #f0f0f0;
        --peditx-hover-bg: #454545;
    }
    .peditx-tabs {
        display: flex;
        gap: 10px;
        margin-bottom: 20px;
        flex-wrap: wrap;
    }
    .peditx-tab-link {
        background-color: #555; /* New dark background for inactive tabs */
        color: #d4d4d4;
        border: none;
        border-radius: 50px; /* Rounded corners for buttons */
        outline: none;
        cursor: pointer;
        padding: 10px 20px;
        font-size: 16px;
        font-weight: bold;
        transition: background-color 0.3s, color 0.3s, box-shadow 0.3s;
        box-shadow: none; /* Inactive tabs have no shadow */
    }
    .peditx-tab-link:hover {
        background: linear-gradient(135deg, #ffae42, #ff8c00);
        color: #1a1a1a;
        box-shadow: 0 4px 15px rgba(0,0,0,0.3);
    }
    .peditx-tab-link.active {
        background: linear-gradient(135deg, #ffae42, #ff8c00);
        color: #1a1a1a; /* Dark text for active tab for contrast */
        font-weight: bold;
        box-shadow: 0 4px 15px rgba(0,0,0,0.3);
    }
    .peditx-tab-content { display: none; }
    .cbi-input-text {
        background-color: var(--peditx-card-bg) !important;
        border: 1px solid var(--peditx-border) !important;
        color: var(--peditx-text-color) !important;
        padding: 10px;
        border-radius: 5px;
        width: 100%;
        box-sizing: border-box;
    }
    .peditx-button {
        font-size: 16px; padding: 10px 25px; color: #1a1a1a; font-weight: bold;
        background: linear-gradient(135deg, #ffae42, #ff8c00);
        border: none; border-radius: 50px; box-shadow: 0 4px 15px rgba(0,0,0,0.3);
        cursor: pointer;
    }
    .peditx-button:disabled { background: #555; cursor: not-allowed; color: #999; }
    .log-container, #interactive_terminal {
        background-color: var(--peditx-dark-bg); color: var(--peditx-text-color);
        font-family: monospace; padding: 15px; border-radius: 8px;
        height: 400px; overflow-y: scroll; white-space: pre-wrap;
        border: 1px solid var(--peditx-border); margin-top: 20px;
    }
    #interactive_terminal { padding: 0; }
    .history-item {
        background-color: var(--peditx-card-bg);
        border: 1px solid var(--peditx-border);
        border-radius: 8px;
        padding: 10px;
        margin-bottom: 10px;
        cursor: pointer;
        transition: background-color 0.2s;
        word-wrap: break-word;
    }
    .history-item:hover {
        background-color: var(--peditx-hover-bg);
    }
    .clear-history-button {
        font-size: 14px;
        padding: 8px 15px;
        color: #fff;
        font-weight: bold;
        background: linear-gradient(135deg, #ff4c4c, #cc0000);
        border: none;
        border-radius: 50px;
        box-shadow: 0 4px 15px rgba(0,0,0,0.3);
        cursor: pointer;
        margin-top: 10px;
        float: right;
    }
</style>

<h2 name="content"><%:PeDitX Commander%></h2>

<div class="cbi-map">
    <div class="peditx-tabs">
        <button class="peditx-tab-link active" onclick="showTab(event, 'smart-installer')">Smart Installer</button>
        <button class="peditx-tab-link" onclick="showTab(event, 'custom-installer')">Custom Installer</button>
    </div>

    <!-- Tab 1: Smart Installer -->
    <div id="smart-installer" class="peditx-tab-content" style="display:block;">
        <div class="cbi-section">
            <div class="cbi-section-descr">
                <p><%:Enter an installer command. The system will try to analyze it and create a form for any required inputs.%></p>
            </div>
            <div class="cbi-value">
                <label class="cbi-value-title" for="script_url"><%:Installer Command%></label>
                <div class="cbi-value-field" style="gap: 10px;">
                    <input type="text" class="cbi-input-text" id="script_url" style="flex-grow: 1;" placeholder="wget https://.../install.sh -O - | sh" />
                    <button id="analyze_button" class="peditx-button"><%:Analyze%></button>
                </div>
            </div>
        </div>
        <div id="dynamic-form-container" class="cbi-section" style="display:none;"></div>
        <div id="execute-container" class="cbi-section" style="display:none; text-align: center; margin-top: 20px;">
            <button id="execute_button" class="peditx-button"><%:Start Installation%></button>
        </div>
        <pre id="log-output" class="log-container">Welcome! Enter an installer command and click Analyze.</pre>

        <!-- Script History Section -->
        <div class="cbi-section">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <h3><a name="history"><%:Script History%></a></h3>
                <button class="clear-history-button" onclick="clearHistory()"><%:Clear History%></button>
            </div>
            <div class="cbi-section-descr">
                <p><%:Click on a past command to load it into the input field above.%></p>
            </div>
            <div id="history-list-container">
                <div>Loading history...</div>
            </div>
        </div>
    </div>

    <!-- Tab 2: Custom/Interactive Installer -->
    <div id="custom-installer" class="peditx-tab-content">
        <div class="cbi-section">
            <div class="cbi-section-descr">
                <p><%:Enter a command to run in the live terminal. You can answer questions (e.g., from whiptail/dialog) directly in the terminal window.%></p>
            </div>
            <div class="cbi-value">
                <label class="cbi-value-title" for="interactive_command_input"><%:Command%></label>
                <div class="cbi-value-field" style="gap: 10px;">
                    <input type="text" class="cbi-input-text" id="interactive_command_input" style="flex-grow: 1;" placeholder="wget ... | sh" />
                    <button id="interactive_execute_button" class="peditx-button"><%:Execute%></button>
                </div>
            </div>
        </div>
        <div id="interactive_terminal" style="height: 450px; border-radius: 8px; overflow: hidden;"></div>
    </div>
</div>

<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/xterm/css/xterm.css" />
<script src="https://cdn.jsdelivr.net/npm/xterm/lib/xterm.js"></script>
<script src="https://cdn.jsdelivr.net/npm/xterm-addon-fit/lib/xterm-addon-fit.js"></script>

<script type="text/javascript">
    var monitorInterval;
    var interactiveTerminalInitialized = false;

    // Load history on initial page load
    window.onload = function() {
        loadHistory();
    };

    function showTab(evt, tabName) {
        var i, tabcontent, tablinks;
        tabcontent = document.getElementsByClassName("peditx-tab-content");
        for (i = 0; i < tabcontent.length; i++) { tabcontent[i].style.display = "none"; }
        tablinks = document.getElementsByClassName("peditx-tab-link");
        for (i = 0; i < tablinks.length; i++) {
            tablinks[i].classList.remove("active");
        }
        document.getElementById(tabName).style.display = "block";
        evt.currentTarget.classList.add("active");

        if (tabName === 'custom-installer' && !interactiveTerminalInitialized) {
            initInteractiveInstaller();
        }
    }
    
    function initInteractiveInstaller() {
        interactiveTerminalInitialized = true;
        const term = new Terminal({ cursorBlink: true, convertEol: true, fontFamily: 'monospace', fontSize: 14, theme: { background: '#1e1e1e', foreground: '#d4d4d4' } });
        const fitAddon = new FitAddon.FitAddon();
        term.loadAddon(fitAddon);
        term.open(document.getElementById('interactive_terminal'));
        fitAddon.fit();
        window.addEventListener('resize', () => fitAddon.fit());

        const wsProtocol = window.location.protocol === 'https:' ? 'wss://' : 'ws://';
        const wsUrl = `${wsProtocol}${window.location.hostname}:7682/ws`;
        const socket = new WebSocket(wsUrl);

        socket.onopen = () => term.onData(data => socket.send(data));
        socket.onmessage = (event) => term.write(event.data);
        socket.onerror = () => term.write('\r\n\x1b[31m[Error] Connection failed.\x1b[0m\r\n');
        socket.onclose = () => term.write('\r\n\x1b[33m[Info] Session closed.\x1b[0m\r\n');

        const executeBtn = document.getElementById('interactive_execute_button');
        const commandInput = document.getElementById('interactive_command_input');
        executeBtn.addEventListener('click', function() {
            if (commandInput.value && socket.readyState === WebSocket.OPEN) {
                socket.send(commandInput.value + '\n');
                commandInput.value = '';
                term.focus();
            }
        });
        commandInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') executeBtn.click(); });
    }

    function pollLog() {
        XHR.get('<%=luci.dispatcher.build_url("admin/peditxos/commander_log")%>', null, function(x, data) {
            if (x && x.status === 200 && data.log !== undefined) {
                var logOutput = document.getElementById('log-output');
                var logContent = data.log;
                if (logOutput.textContent !== logContent) {
                    logOutput.textContent = logContent;
                    logOutput.scrollTop = logOutput.scrollHeight;
                }
                if (logContent.includes(">>> SCRIPT FINISHED <<<")) {
                    if (monitorInterval) { clearInterval(monitorInterval); monitorInterval = null; }
                    document.getElementById('execute_button').disabled = false;
                    document.getElementById('analyze_button').disabled = false;
                }
            }
        });
    }

    function loadHistory() {
        var container = document.getElementById('history-list-container');
        container.innerHTML = '<div>Loading history...</div>';
        XHR.get('<%=luci.dispatcher.build_url("admin/peditxos/commander_history")%>', null, function(x, data) {
            if (x && x.status === 200 && data.history !== undefined) {
                container.innerHTML = '';
                if (data.history.length > 0) {
                    data.history.reverse().forEach(function(item) {
                        var div = document.createElement('div');
                        div.className = 'history-item';
                        div.textContent = item.url;
                        div.onclick = function() {
                            document.getElementById('script_url').value = item.url;
                        };
                        container.appendChild(div);
                    });
                } else {
                    container.innerHTML = '<div>No past commands found.</div>';
                }
            } else {
                container.innerHTML = '<div>Error loading history.</div>';
            }
        });
    }
    
    function clearHistory() {
        XHR.get('<%=luci.dispatcher.build_url("admin/peditxos/commander_clear_history")%>', null, function(x, data) {
            if (x && x.status === 200 && data.success) {
                loadHistory(); // Reload the history list after clearing
                document.getElementById('log-output').textContent = 'History has been cleared.';
            } else {
                document.getElementById('log-output').textContent = 'Error: Could not clear history.';
            }
        });
    }

    document.getElementById('analyze_button').addEventListener('click', function() {
        var url = document.getElementById('script_url').value;
        if (!url) { alert('Please enter an installer command.'); return; }
        var button = this;
        button.disabled = true;
        document.getElementById('log-output').textContent = 'Analyzing script...';
        var formContainer = document.getElementById('dynamic-form-container');
        formContainer.innerHTML = '';
        document.getElementById('execute-container').style.display = 'none';
        XHR.get('<%=luci.dispatcher.build_url("admin/peditxos/commander_analyze")%>', { url: url }, function(x, data) {
            button.disabled = false;
            if (x && x.status === 200 && data.success) {
                document.getElementById('log-output').textContent = 'Analysis complete. Please fill in the required information below.';
                if (data.params && data.params.length > 0) {
                    data.params.forEach(function(param) {
                        var div = document.createElement('div'); div.className = 'cbi-value';
                        var label = document.createElement('label'); label.className = 'cbi-value-title'; label.innerText = param.prompt;
                        var fieldDiv = document.createElement('div'); fieldDiv.className = 'cbi-value-field';
                        var input = document.createElement('input'); input.type = 'text'; input.className = 'cbi-input-text'; input.id = 'param_' + param.variable; input.dataset.variable = param.variable;
                        fieldDiv.appendChild(input); div.appendChild(label); div.appendChild(fieldDiv); formContainer.appendChild(div);
                    });
                    formContainer.style.display = 'block';
                } else {
                    document.getElementById('log-output').textContent += '\nNo inputs required. Ready to install.';
                }
                document.getElementById('execute-container').style.display = 'block';
            } else {
                document.getElementById('log-output').textContent = 'Analysis failed: ' + (data.error || 'Could not analyze script.');
            }
        });
    });

    document.getElementById('execute_button').addEventListener('click', function() {
        var url = document.getElementById('script_url').value;
        var params = {};
        document.querySelectorAll('#dynamic-form-container input').forEach(function(input) { params[input.dataset.variable] = input.value; });
        var button = this;
        button.disabled = true;
        document.getElementById('analyze_button').disabled = true;
        document.getElementById('log-output').textContent = 'Starting installation...\n\n';
        XHR.get('<%=luci.dispatcher.build_url("admin/peditxos/commander_run")%>', { url: url, params: JSON.stringify(params) }, function(x, data) {
            if (x && x.status === 200 && data.success) {
                monitorInterval = setInterval(pollLog, 2000);
            } else {
                button.disabled = false;
                document.getElementById('analyze_button').disabled = false;
                document.getElementById('log-output').textContent = 'Error starting installation.';
            }
        });
    });
</script>

<%+footer%>
EoL

# --- Runner Script Creation (for Smart Installer) ---
echo ">>> Creating the smart runner script..."
cat > /usr/bin/commander_runner.sh << 'EOF'
#!/bin/sh
#================================================================
# LuCI Commander Runner (v42 - Final)
#================================================================
# This version uses the stable 'analyze' logic while maintaining
# a secure 'execute' script, fixing the freezing issue.
#================================================================

ACTION="$1"
URL_COMMAND="$2"
PARAMS_JSON="$3"
LOG_FILE="/tmp/commander_log.txt"
LOCK_FILE="/tmp/commander.lock"
SCRIPT_FILE="/tmp/installer_script.sh"

# Function to extract URL from the command string
extract_url() {
    echo "$1" | grep -oE '(http|https)://[^ |"]+' | head -n 1
}

# Function to analyze the script
analyze_script() {
    URL=$(extract_url "$URL_COMMAND")
    if [ -z "$URL" ]; then echo '{"success": false, "error": "Could not find a valid URL."}'; exit 1; fi
    
    # Use curl for better compatibility and error handling
    curl -sSL --fail "$URL" -o "$SCRIPT_FILE"
    if [ $? -ne 0 ]; then echo '{"success": false, "error": "Failed to download script."}'; exit 1; fi

    # Analyze for 'read VAR' patterns and prompts
    PARAMS=$(grep -E '^\s*read\s+.*[a-zA-Z0-9_]+' "$SCRIPT_FILE" | sed -E 's/^\s*read\s+(-p\s*"[^"]*"\s+)?([a-zA-Z0-9_]+).*$/\2/')
    
    echo '{"success": true, "params": ['
    FIRST=true
    for VAR in $PARAMS; do
        if [ "$FIRST" = "false" ]; then echo -n ","; fi
        
        # Try to find a prompt for the variable using various common patterns
        PROMPT=$(grep -B 1 "read.*${VAR}" "$SCRIPT_FILE" | head -n 1 | grep -oE 'echo\s*(-n\s*)?"[^"]*"' | sed -E 's/.*echo\s*(-n\s*)?"([^"]*)"/\2/')
        if [ -z "$PROMPT" ]; then PROMPT=$(grep "read.*-p" "$SCRIPT_FILE" | grep "$VAR" | sed -E 's/.*read.*-p\s*"([^"]*)".*/\1/'); fi
        if [ -z "$PROMPT" ]; then PROMPT="Enter value for ${VAR}:"; fi
        
        echo -n "{\"variable\": \"$VAR\", \"prompt\": \"$PROMPT\"}"
        FIRST=false
    done
    echo ']}'
}

# Function to execute the script
execute_script() {
    if [ -f "$LOCK_FILE" ]; then
        echo ">>> Another script is running." > "$LOG_FILE"; echo ">>> SCRIPT FINISHED <<<" >> "$LOG_FILE"; exit 1;
    fi
    touch "$LOCK_FILE"; trap 'rm -f "$LOCK_FILE"' EXIT
    (
        echo ">>> Starting script at $(date)"
        # Simple JSON parsing without jq
        echo "$PARAMS_JSON" | sed 's/[{}" ]//g' | tr ',' '\n' | while IFS=: read -r key value; do
            export "$key"="$value"
        done
        echo ">>> Executing script from: $URL_COMMAND"
        echo "--------------------------------------"
        
        # Execute the pre-downloaded file instead of 'eval'
        sh "$SCRIPT_FILE"
        
        EXIT_CODE=$?
        echo "--------------------------------------"
        echo "Exit Code: $EXIT_CODE"
        echo ">>> SCRIPT FINISHED <<<"
    ) > "$LOG_FILE" 2>&1
}

case "$ACTION" in
    analyze) analyze_script ;;
    execute) execute_script ;;
esac
EOF
chmod +x /usr/bin/commander_runner.sh

# --- Service Creation (for Interactive Installer) ---
echo ">>> Creating the interactive session service..."
# FIX: A fully compliant init.d script
cat > /etc/init.d/luci_commander_ttyd <<'EoL'
#!/bin/sh /etc/rc.common
START=99
STOP=10
USE_PROCD=1
PROG=/usr/bin/ttyd

start_service() {
    procd_open_instance
    procd_set_param command $PROG -p 7682 /bin/ash -i
    procd_set_param respawn
    procd_close_instance
}

stop_service() {
    : # This is a null command to make the function syntactically valid.
}
EoL
# CRITICAL FIX: Add execute permissions to the init script
chmod +x /etc/init.d/luci_commander_ttyd
echo "Service script created and made executable."

# --- Finalizing ---
echo ">>> Finalizing installation..."
/etc/init.d/luci_commander_ttyd enable
/etc/init.d/luci_commander_ttyd restart
rm -rf /tmp/luci-*
/etc/init.d/uhttpd restart
echo ">>> PeDitX Commander is ready."
