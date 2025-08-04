#!/bin/sh

#================================================================
# LuCI Commander Installer Script (v38 - History Clear & Format)
#================================================================
# This version adds a clear button and improved formatting to the
# command history feature.
#================================================================

# --- Cleanup ---
echo ">>> Cleaning up old versions..."
rm -f /usr/lib/lua/luci/controller/commander.lua
rm -f /usr/lib/lua/luci/view/commander.htm
rm -f /usr/bin/commander_runner.sh
rm -f /etc/config/commander_history.log
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

# Create LuCI Controller (with History Clear API)
cat > /usr/lib/lua/luci/controller/commander.lua <<'EoL'
module("luci.controller.commander", package.seeall)

function index()
    entry({"admin", "peditxos"}, firstchild(), "PeDitXOS Tools", 50).dependent=true
    entry({"admin", "peditxos", "commander"}, template("commander"), "Commander", 30).dependent = true
    
    entry({"admin", "peditxos", "commander_analyze"}, call("analyze_script")).json = true
    entry({"admin", "peditxos", "commander_run"}, call("run_script")).json = true
    entry({"admin", "peditxos", "commander_log"}, call("get_log")).json = true
    entry({"admin", "peditxos", "commander_history"}, call("handle_history")).json = true
end

function handle_history()
    local history_file = "/etc/config/commander_history.log"
    if luci.http.formvalue("action") == "clear" then
        -- Clear history
        local f = io.open(history_file, "w")
        if f then f:close() end
        luci.http.prepare_content("application/json")
        luci.http.write_json({success = true})
    elseif luci.http.formvalue("url") then
        -- Write to history
        local url_to_add = luci.http.formvalue("url")
        local f_read = io.open(history_file, "r")
        local exists = false
        if f_read then
            for line in f_read:lines() do
                if line == url_to_add then
                    exists = true
                    break
                end
            end
            f_read:close()
        end
        if not exists then
            local f_append = io.open(history_file, "a")
            if f_append then
                f_append:write(url_to_add .. "\n")
                f_append:close()
            end
        end
        luci.http.prepare_content("application/json")
        luci.http.write_json({success = true})
    else
        -- Read history
        local history = {}
        local f = io.open(history_file, "r")
        if f then
            for line in f:lines() do
                table.insert(history, line)
            end
            f:close()
        end
        luci.http.prepare_content("application/json")
        luci.http.write_json({history = history})
    end
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

function run_script()
    local url = luci.http.formvalue("url")
    local params = luci.http.formvalue("params")
    if not url or url == "" then
        luci.http.prepare_content("application/json")
        luci.http.write_json({success = false, error = "URL is missing"})
        return
    end
    luci.sys.exec("nohup /usr/bin/commander_runner.sh execute \"" .. url .. "\" '" .. params .. "' >/dev/null 2>&1 &")
    luci.http.prepare_content("application/json")
    luci.http.write_json({success = true})
end
EoL

# Create LuCI View (with new styles and history section)
cat > /usr/lib/lua/luci/view/commander.htm <<'EoL'
<%+header%>

<style>
    :root {
        --peditx-primary: #00b5e2;
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
        font-size: 16px; padding: 10px 25px; color: #1a1a1a; font-weight: bold;
        background: #555;
        border: none; border-radius: 50px; box-shadow: 0 4px 15px rgba(0,0,0,0.3);
        cursor: pointer;
        transition: background 0.3s ease, transform 0.2s ease;
        color: #ddd;
    }
    .peditx-tab-link.active {
        background: linear-gradient(135deg, #ffae42, #ff8c00);
        color: #1a1a1a;
        transform: translateY(-2px);
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
    #history-container {
        margin-top: 20px;
        padding: 15px;
        background: var(--peditx-card-bg);
        border: 1px solid var(--peditx-border);
        border-radius: 8px;
    }
    #history-list {
        list-style: none; padding: 0; margin: 0; max-height: 150px; overflow-y: auto;
    }
    .history-item {
        padding: 8px;
        cursor: pointer;
        border-bottom: 1px solid var(--peditx-border);
        transition: background-color 0.2s;
        word-break: break-all;
    }
    .history-item:last-child { border-bottom: none; }
    .history-item:hover { background-color: var(--peditx-hover-bg); }
    .clear-button {
        background: linear-gradient(135deg, #ff6b6b, #ff4d4d);
        font-size: 12px;
        padding: 5px 15px;
    }
    .clear-button:hover {
        background: linear-gradient(135deg, #ff4d4d, #e03e3e);
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
        <div id="history-container">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
                <h4>History</h4>
                <button id="clear_history_button" class="peditx-button clear-button">Clear</button>
            </div>
            <ul id="history-list"></ul>
        </div>
    </div>

    <!-- Tab 2: Custom/Interactive Installer -->
    <div id="custom-installer" class="peditx-tab-content">
        <div class="cbi-section">
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

    function showTab(evt, tabName) {
        var i, tabcontent, tablinks;
        tabcontent = document.getElementsByClassName("peditx-tab-content");
        for (i = 0; i < tabcontent.length; i++) { tabcontent[i].style.display = "none"; }
        tablinks = document.getElementsByClassName("peditx-tab-link");
        for (i = 0; i < tablinks.length; i++) { tablinks[i].className = tablinks[i].className.replace(" active", ""); }
        document.getElementById(tabName).style.display = "block";
        evt.currentTarget.className += " active";

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
        XHR.get('<%=luci.dispatcher.build_url("admin/peditxos/commander_history")%>', null, function(x, data) {
            if (x && x.status === 200 && data.history) {
                var historyList = document.getElementById('history-list');
                historyList.innerHTML = '';
                if (data.history.length === 0) {
                    historyList.innerHTML = '<li class="history-item" style="cursor:default; color:#888;">No history yet.</li>';
                } else {
                    data.history.reverse().forEach(function(cmd) {
                        var li = document.createElement('li');
                        li.className = 'history-item';
                        
                        var filename = "Script";
                        var match = cmd.match(/([^/]+\.sh)/);
                        if (match && match[1]) {
                            filename = match[1];
                        }
                        
                        li.innerHTML = `<strong style="color: var(--peditx-primary);">${filename}:</strong> ${cmd}`;
                        li.onclick = function() {
                            document.getElementById('script_url').value = cmd;
                        };
                        historyList.appendChild(li);
                    });
                }
            }
        });
    }

    function clearHistory() {
        XHR.get('<%=luci.dispatcher.build_url("admin/peditxos/commander_history")%>', { action: 'clear' }, function() {
            loadHistory();
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
                XHR.get('<%=luci.dispatcher.build_url("admin/peditxos/commander_history")%>', { url: url }, function() {
                    loadHistory();
                });
                monitorInterval = setInterval(pollLog, 2000);
            } else {
                button.disabled = false;
                document.getElementById('analyze_button').disabled = false;
                document.getElementById('log-output').textContent = 'Error starting installation.';
            }
        });
    });

    document.getElementById('clear_history_button').addEventListener('click', clearHistory);
    loadHistory();
</script>

<%+footer%>
EoL

# --- Runner Script Creation (for Smart Installer) ---
echo ">>> Creating the smart runner script..."
cat > /usr/bin/commander_runner.sh << 'EOF'
#!/bin/sh
ACTION="$1"
URL_COMMAND="$2"
PARAMS_JSON="$3"
LOG_FILE="/tmp/commander_log.txt"
LOCK_FILE="/tmp/commander.lock"
SCRIPT_FILE="/tmp/installer_script.sh"

extract_url() {
    echo "$1" | grep -oE '(http|https)://[^ |"]+' | head -n 1
}

analyze_script() {
    URL=$(extract_url "$URL_COMMAND")
    if [ -z "$URL" ]; then echo '{"success": false, "error": "Could not find a valid URL."}'; exit 1; fi
    curl -sSL --fail "$URL" -o "$SCRIPT_FILE"
    if [ $? -ne 0 ]; then echo '{"success": false, "error": "Failed to download script."}'; exit 1; fi
    PARAMS=$(grep -E '^\s*read\s+.*[a-zA-Z0-9_]+' "$SCRIPT_FILE" | sed -E 's/^\s*read\s+(-p\s*"[^"]*"\s+)?([a-zA-Z0-9_]+).*$/\2/')
    echo '{"success": true, "params": ['
    FIRST=true
    for VAR in $PARAMS; do
        if [ "$FIRST" = "false" ]; then echo ","; fi
        PROMPT=$(grep -B 1 "read.*${VAR}" "$SCRIPT_FILE" | head -n 1 | grep -oE 'echo\s*(-n\s*)?"[^"]*"' | sed -E 's/.*echo\s*(-n\s*)?"([^"]*)"/\2/')
        if [ -z "$PROMPT" ]; then PROMPT=$(grep "read.*-p" "$SCRIPT_FILE" | grep "$VAR" | sed -E 's/.*read.*-p\s*"([^"]*)".*/\1/'); fi
        if [ -z "$PROMPT" ]; then PROMPT="Enter value for ${VAR}:"; fi
        echo "{\"variable\": \"$VAR\", \"prompt\": \"$PROMPT\"}"
        FIRST=false
    done
    echo ']}'
}

execute_script() {
    if [ -f "$LOCK_FILE" ]; then
        echo ">>> Another script is running." > "$LOG_FILE"; echo ">>> SCRIPT FINISHED <<<" >> "$LOG_FILE"; exit 1;
    fi
    touch "$LOCK_FILE"; trap 'rm -f "$LOCK_FILE"' EXIT
    (
        echo ">>> Starting script at $(date)"
        echo "$PARAMS_JSON" | sed 's/[{}" ]//g' | tr ',' '\n' | while IFS=: read -r key value; do
            export "$key"="$value"
        done
        echo ">>> Executing: $URL_COMMAND"
        echo "--------------------------------------"
        eval "$URL_COMMAND"
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
    :
}
EoL
chmod +x /etc/init.d/luci_commander_ttyd
echo "Service script created and made executable."

# --- Finalizing ---
echo ">>> Finalizing installation..."
touch /etc/config/commander_history.log
/etc/init.d/luci_commander_ttyd enable
/etc/init.d/luci_commander_ttyd restart
rm -rf /tmp/luci-*
/etc/init.d/uhttpd restart
echo ">>> PeDitX Commander is ready."
