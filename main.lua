SLASH = 53

local key_sequence = require 'key_sequence'
local util = require 'util'

local execute = diversion.execute
local send_event = diversion.send_event

KEYS_DOWN = {}
KEYBOARD = 0
PUGIO = 1
KEYS_DOWN[KEYBOARD] = {}
KEYS_DOWN[PUGIO] = {}
OVERRIDES = {}
SEQUENCE_DRIVER = nil

local function create_mouse_callback(device, key, axis, direction)
    return function(value)
        if KEYS_DOWN[device][L_PIPE] then
            if value == 1 or value == 2 then
                if KEYS_DOWN[device][D] and KEYS_DOWN[device][F] then
                    send_event(EV_REL, axis, 10 * direction)
                elseif KEYS_DOWN[device][D] then
                    send_event(EV_REL, axis, 50 * direction)
                elseif KEYS_DOWN[device][F] then
                    send_event(EV_REL, axis, 4 * direction)
                else
                    send_event(EV_REL, axis, 200 * direction)
                end
            end
        else
            send_event(EV_KEY, key, value)
        end
    end
end

local function send_if_other_down(device, other, normal, special)
    return function(value)
        if KEYS_DOWN[device][other] then
            send_event(EV_KEY, special, value)
        else
            send_event(EV_KEY, normal, value)
        end
    end
end

function main(hostname)
    local rev_mouse = false
    local function disabled() end
    local function swap_keys(device, a, b)
        local function swap(event)
            if not OVERRIDES[device] then return end
            if not OVERRIDES[device][event] then return end
            local prev_a = OVERRIDES[device][event][a]
            local prev_b = OVERRIDES[device][event][b]
            if prev_b ~= nil then
                OVERRIDES[device][event][a] = prev_b
            else
                OVERRIDES[device][event][a] = function(value) send_event(event, b, value) end
            end
            if prev_a ~= nil then
                OVERRIDES[device][event][b] = prev_a
            else
                OVERRIDES[device][event][b] = function(value) send_event(event, a, value) end
            end
        end
        swap(EV_KEY)
        swap(EV_REL)
    end
    OVERRIDES = {
        [KEYBOARD] = {
            [EV_KEY] = {
                [R_FN] = disabled,
                [L_PIPE] = disabled,
                [MENU] = disabled,
                [L_ALT] = disabled,
                [D] = function(value)
                    if not KEYS_DOWN[KEYBOARD][L_PIPE] then
                        send_event(EV_KEY, D, value)
                    end
                end,
                [F] = function(value)
                    if not KEYS_DOWN[KEYBOARD][L_PIPE] then
                        send_event(EV_KEY, F, value)
                    end
                end,
                [SPACE] = function(value)
                    if KEYS_DOWN[KEYBOARD][L_PIPE] then
                        send_event(EV_KEY, L_BUTTON, value)
                    else
                        send_event(EV_KEY, SPACE, value)
                    end
                end,
                [N] = function(value)
                    if KEYS_DOWN[KEYBOARD][L_PIPE] then
                        send_event(EV_KEY, R_BUTTON, value)
                    else
                        send_event(EV_KEY, N, value)
                    end
                end,
                [M] = function(value)
                    if KEYS_DOWN[KEYBOARD][L_PIPE] then
                        send_event(EV_KEY, M_BUTTON, value)
                    else
                        send_event(EV_KEY, M, value)
                    end
                end,
                [P] = function(value)
                    if KEYS_DOWN[KEYBOARD][L_PIPE] then
                        if value == 1 or value == 2 then
                            send_event(EV_REL, WHEEL, 100)
                        end
                    else
                        send_event(EV_KEY, P, value)
                    end
                end,
                [Z] = function(value)
                    if not KEYS_DOWN[KEYBOARD][L_PIPE] then
                        send_event(EV_KEY, Z, value)
                    end
                end,
                [X] = function(value)
                    if not KEYS_DOWN[KEYBOARD][L_PIPE] then
                        send_event(EV_KEY, X, value)
                    end
                end,
                [SEMICOLON] = function(value)
                    if KEYS_DOWN[KEYBOARD][L_PIPE] then
                        if value == 1 or value == 2 then
                            send_event(EV_REL, WHEEL, -100)
                        end
                    else
                        send_event(EV_KEY, SEMICOLON, value)
                    end
                end,
                [H] = hostname == "nixos-lati" and send_if_other_down(KEYBOARD, L_ALT, H, LEFT) or nil,
                [J] = hostname == "nixos-lati" and send_if_other_down(KEYBOARD, L_ALT, J, DOWN) or nil,
                [K] = hostname == "nixos-lati" and send_if_other_down(KEYBOARD, L_ALT, K, UP) or nil,
                [L] = hostname == "nixos-lati" and send_if_other_down(KEYBOARD, L_ALT, L, RIGHT) or nil,
                [ZERO] = hostname == "nixos-lati" and send_if_other_down(KEYBOARD, L_ALT, ZERO, HOME) or nil,
                [M] = hostname == "nixos-lati" and send_if_other_down(KEYBOARD, L_ALT, M, END) or nil,
                [SEMICOLON] = hostname == "nixos-lati" and send_if_other_down(KEYBOARD, L_ALT, SEMICOLON, DELETE) or nil,
                [N] = hostname == "nixos-lati" and send_if_other_down(KEYBOARD, L_ALT, N, BACKSPACE) or nil,
                [FOUR] = hostname == "nixos-lati" and send_if_other_down(KEYBOARD, L_ALT, FOUR, F4) or nil,
                [VOL_DOWN] = function(value)
                    if KEYS_DOWN[KEYBOARD][L_CTRL] then
                        util.change_sink_volume("Spotify", '-5%')
                    else
                        send_event(EV_KEY, VOL_DOWN, value)
                    end
                end,
                [VOL_UP] = function(value)
                    if KEYS_DOWN[KEYBOARD][L_CTRL] then
                        util.change_sink_volume("Spotify", '+5%')
                    else
                        send_event(EV_KEY, VOL_UP, value)
                    end
                end,
                [INSERT] = function(value)
                    if KEYS_DOWN[KEYBOARD][L_CTRL] then
                        diversion.reload()
                    else
                        send_event(EV_KEY, PAUSE_BREAK, value)
                    end
                end,
                [ENTER] = (function()
                    local down_timestamp = 0
                    return function(value, time)
                        if hostname ~= "nixos-lati" then
                            return send_event(EV_KEY, ENTER, value)
                        end
                        if value == 1 then
                            down_timestamp = time
                            send_event(EV_KEY, R_SHIFT, 1)
                        end
                        if value == 0 then
                            send_event(EV_KEY, R_SHIFT, 0)
                            if time - down_timestamp < 0.2 then
                                send_event(EV_KEY, ENTER, 1)
                                send_event(EV_KEY, ENTER, 0)
                            end
                        end
                    end
                end)(),
                [R_SHIFT] = function(value)
                    if hostname == "nixos-lati" then
                        send_event(EV_KEY, L_ALT, value)
                    else
                        send_event(EV_KEY, R_SHIFT, value)
                    end
                end
            }
        },
        [PUGIO] = {
            [EV_REL] = {
                [X_AXIS] = function(value)
                    if KEYS_DOWN[KEYBOARD][L_PIPE] and KEYS_DOWN[KEYBOARD][Z] then
                    else
                        if rev_mouse then
                            send_event(EV_REL, X_AXIS, -value)
                        else
                            send_event(EV_REL, X_AXIS, value)
                        end
                    end
                end,
                [Y_AXIS] = function(value)
                    if KEYS_DOWN[KEYBOARD][L_PIPE] and KEYS_DOWN[KEYBOARD][X] then
                    else
                        if rev_mouse then
                            send_event(EV_REL, Y_AXIS, -value)
                        else
                            send_event(EV_REL, Y_AXIS, value)
                        end
                    end
                end,
                [WHEEL_PIXEL] = function(value)
                    if not KEYS_DOWN[KEYBOARD][L_PIPE] then
                        send_event(EV_REL, WHEEL_PIXEL, value)
                    end
                end
            },
            [EV_KEY] = {
                [L_BUTTON] = function(value)
                    send_event(EV_KEY, L_BUTTON, value)
                end
            }
        }
    }

    local vol_up_seq = key_sequence.create({ G, K }, function()
        if KEYS_DOWN[KEYBOARD][L_SHIFT] then
            util.change_sink_volume("Spotify", "+2%")
        else
            send_event(EV_KEY, VOL_UP, 1)
            send_event(EV_KEY, VOL_UP, 0)
        end
    end)
    local vol_down_seq = key_sequence.create({ G, J }, function()
        if KEYS_DOWN[KEYBOARD][L_SHIFT] then
            util.change_sink_volume("Spotify", "-2%")
        else
            send_event(EV_KEY, VOL_DOWN, 1)
            send_event(EV_KEY, VOL_DOWN, 0)
        end
    end)
    local deskpi = "deskpi"
    local light_off_seq = key_sequence.create({ G, LT }, function()
        execute("curl", { "http://" .. deskpi .. ":8000/off" })
    end)
    local light_on_seq = key_sequence.create({ G, GT }, function()
        execute("curl", { "http://" .. deskpi .. ":8000/on" })
    end)
    local rev_mouse_toggle_seq = key_sequence.create({ R_ALT, R, E }, function()
        rev_mouse = not rev_mouse
    end)
    local repeat_command_seq = key_sequence.create({ G, MINUS }, function ()
        diversion.spawn("nc", { "127.0.0.1", "7821" })("run")
    end)
    function switch_to_audio_output(port)
        if hostname ~= "nixos-desktop" then
            return
        end
        print("switching to " .. port)
        execute("amixer", { "-c", "Generic", "set", "Auto-Mute Mode", "Disabled" }):next(function(output)
            if output.code ~= 0 then
                print(output.code, output.stderr, output.stdout)
            end
        end)
        execute("pactl", { "set-sink-port", "alsa_output.pci-0000_0a_00.4.analog-stereo", port }):next(function(output)
            if output.code ~= 0 then
                print(output.code, output.stderr, output.stdout)
            end
        end)
    end
    local HEADPHONES = "analog-output-lineout"
    local SPEAKERS = "analog-output-headphones"
    switch_to_audio_output(HEADPHONES)
    local switch_audio_output_seq = key_sequence.create({ G, SLASH }, (function()
        local ports = { HEADPHONES, SPEAKERS }
        local current = ports[1]
        return function()
            local port = ports[current == ports[1] and 2 or 1]
            switch_to_audio_output(port)
            current = port
        end
    end)())

    local sequences = {
        [KEYBOARD] = {
            vol_down_seq,
            vol_up_seq,
            rev_mouse_toggle_seq,
            light_off_seq,
            light_on_seq,
            switch_audio_output_seq,
            repeat_command_seq,
        },
    }

    if hostname == "nixos-lati" then
        swap_keys(KEYBOARD, ESCAPE, CAPS_LOCK)
    end

    SEQUENCE_DRIVER = key_sequence.driver(sequences)
end

local function on_event(device, ty, code, value, time)
    local keys_down = KEYS_DOWN[device]
    if ty == EV_KEY then
        keys_down[code] = value ~= 0
    end
    if keys_down[INSERT] then
        print(ty, code, value)
        return
    end
    if SEQUENCE_DRIVER and SEQUENCE_DRIVER(device, ty, code, value) then return end
    local device_override = OVERRIDES[device]
    if device_override ~= nil then
        local ty_override = device_override[ty]
        if ty_override ~= nil then
            local override = ty_override[code]
            if override ~= nil then
                override(value, time)
                return
            end
        end
    end
    send_event(ty, code, value)
end

diversion.listen(on_event)

execute("hostname", {}):next(function (result)
    local hostname = result.stdout:gsub("%s+", "")
    return execute("whoami", {}):next(function (output)
        return { user = output.stdout, hostname = hostname }
    end)
end):next(function(info)
    main(info.hostname)
    print("started at " .. os.date("%Y-%m-%d %H:%M:%S"))
    print("running as user", info.user)
    util.notify_send("Diversion started!")
end)

