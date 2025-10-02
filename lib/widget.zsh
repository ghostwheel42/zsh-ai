#!/usr/bin/env zsh

# ZLE widget and key binding for zsh-ai

# Custom widget to intercept Enter key
_zsh_ai_accept_line() {
    # Execute normally if line does not start with "# " or contains newline
    [[ ! "${BUFFER}" =~ ^"#${ZSH_AI_GUARD} " || "${BUFFER}" == *$'\n'* ]] && {
        zle .accept-line
        return
    }

    # Extract the query (remove the "# " prefix)
    local query="${BUFFER:$((${#ZSH_AI_GUARD}+2))}"

    # Add a loading indicator with animation
    local saved_buffer="${BUFFER}"

    # Animation frames - rotating dots
    local dots="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local frame=0

    # Disable job control notifications
    setopt local_options no_monitor no_notify

    # Start the API query in background using the shared function
    # Only redirect stdout, let stderr go to /dev/null to avoid mixing error output
    coproc _zsh_ai_query "${query}"
    local pid=$!

    # Animate spinner while reading response
    local output=()
    while kill -0 ${pid} 2>/dev/null; do
        if read -rpt 0.1 line; then
            output+=("${line}")
            sleep 0.1
        fi
        BUFFER="${saved_buffer} ${dots[$((frame++ % ${#dots} + 1))]}"
        zle redisplay
        zle -R
    done
    while read -rpt 0.1 line; do
        output+=("${line}")
    done

    # Handle response according to exit code
    local cmd="${${${(F)output}##[[:space:]]}%%[[:space:]]}"
    if wait ${pid} && [[ -n "${cmd}" ]]; then
        # Replace the buffer with the generated command
        BUFFER="${cmd}"
        # And move cursor to end of line
        CURSOR=${#BUFFER}
    else
        # Show error and clear buffer
        print -P " %F{red}❌ Failed to generate command%f"
        [[ -n "${cmd}" ]] && print -P "%F{red}${cmd}%f"
        BUFFER=""
    fi

    # Redraw the prompt
    zle reset-prompt
}

# Create the widget and bind it
_zsh_ai_init_widget() {
    zle -N accept-line _zsh_ai_accept_line
}
