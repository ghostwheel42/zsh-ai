#!/usr/bin/env zsh

# Utility functions for zsh-ai

# Function to get the standardized system prompt for all providers
_zsh_ai_get_system_prompt() {
    local context="$(_zsh_ai_build_context)"
    local extra="${ZSH_AI_PROMPT_EXTEND}${ZSH_AI_PROMPT_EXTEND:+\n\n}"
    local prompt="
        You are a zsh command generator. Generate syntactically correct zsh commands
        ready to be copied directly into the user's terminal and based on the user's
        natural language request.

        IMPORTANT RULES:
        1. Output ONLY the raw command - no explanations, no markdown, no backticks!
        2. For arguments containing spaces or special characters, use single quotes!
        3. Use double quotes only when variable expansion is needed!
        4. Properly escape special characters within quotes!

        Examples:
        - echo 'Hello World!' (spaces require quotes)
        - echo \"Current user: \$USER\" (variable expansion needs double quotes)
        - grep 'pattern with spaces' file.txt
        - find . -name '*.txt' (glob patterns in quotes)

        ${extra}Context:

        ${context}
    "
    prompt="${${${(*)prompt//        /}##[[:space:]]}%%[[:space:]]}"
    print -r "${prompt}"
}

# JSON escape functions
_zsh_ai_json_strings() {
    if command -v jq &>/dev/null; then
        if [[ $# -eq 1 ]]; then
            jq -cMn --arg var "${1:-}" '$var'
        else
            jq -cMn --args '$ARGS.positional' "$@"
        fi
    elif [[ $# -eq 1 ]]; then
        _zsh_ai_json_string "${1:-}"
    else
        local v s=""
        printf "["
        for v in "$@"; do
            printf '%s%s' "${s}" "$(_zsh_ai_json_string "${v}")"
            s=","
        done
        printf "]\n"
    fi
}
_zsh_ai_json_string() {
    printf '"%s"\n' "${${${${${${${${1:-}//\\/\\\\}//\"/\\\"}//$'\n'/\\n}//$'\r'/\\r}//$'\t'/\\t}//$'\b'/\\b}//$'\f'/\\f}"
}

# JSON parser to dump key+values or extract a value
_zsh_ai_dump_json() {
    local json="${1:-}" selector="${2:-}"

    if command -v jq &>/dev/null; then
        if [[ -n "${selector}" ]]; then
            jq -re "${selector} // empty" <<<"${json}"
        else
            jq -re 'paths(scalars) as $p | "\([$p[] | if (type=="number") then "[\(.)]" else ".\(.)" end ] | join(""))=\(getpath($p) | tojson)"' <<<"${json}"
        fi
        return
    fi

    local path=() sep=() obj=0
    local pos rest token spos location

    for (( pos=1; pos<=${#json}; pos++ )); do

        # skip whitespace
        pos=$((pos+${#${(*)${json:$((pos-1))}%%[[:graph:]]*}}))
        rest=$((pos-1))

        # process next token
        case "${json[${pos}]}" in
            "")
                # eof
                >&2 print "parse error: Unfinished JSON term at EOF\n"
                return 5
                ;;
            ${~sep[-1]})
                # object/array separator - process and continue
                case "${json[${pos}]}" in
                    ':')
                        # key-value separator
                        if [[ "${path[-1]}" == $'\0' ]]; then
                            >&2 print "parse error: Expected string key before ':' at position ${pos}"
                            return 5
                        fi
                        sep[-1]="[,}]"
                        ;;
                    []}])
                        # object/array closed
                        path[-1]=()
                        sep[-1]=()
                        [[ ${#path} -eq 0 ]] && : $((obj++))
                        ;;
                    ',')
                        # object/array item separator - toggle object k/v mode
                        [[ "${sep[-1]}" == "[,}]" ]] && sep[-1]="[:}]" && path[-1]=$'\0'
                        ;;
                esac
                continue
                ;;
            '{')
                # object - update path and separators and continue
                path+=($'\0')
                sep+=('[:}]')
                continue
                ;;
            '[')
                # array - update path and separators and continue
                path+=($'\0[0]')
                sep+=('[],]')
                continue
                ;;
            '"')
                # string - find the closing quote, respecting escaped quotes
                token='"'
                spos=${pos}
                while [[ ${spos} -le ${#json} ]]; do
                    # get json up to the next quote
                    token+="${${json:${spos}}%%\"*}\""
                    # check if the quote was escaped
                    [[ "${token[-2]}" == '\' ]] || {
                        # Not escaped, end of string
                        break
                    }
                    # it was escaped, continue scanning
                    spos=$((pos+${#token}-1))
                done
                if [[ ${spos} -gt ${#json} ]]; then
                    >&2 print "parse error: Unfinished string at EOF at position ${pos}"
                    return 5
                fi
                ;;
            [0-9-])
                # number
                if [[ "${json:${rest}}" =~ ^-?[0-9]+\\.?[0-9]*[eE]?[+-]?[0-9]* ]]; then
                    token="${MATCH}"
                else
                    >&2 print "parse error: Invalid numeric literal at position ${pos}"
                    return 5
                fi
                ;;
            *)
                # literal
                for prefix in true false null; do
                    if [[ "${json:${rest}:${#prefix}}" == "${prefix}" ]]; then
                        token="${prefix}"
                        break
                    fi
                done
                if [[ -z "${token}" ]]; then
                    >&2 print "parse error: Invalid literal at position ${pos}"
                    return 5
                fi
                ;;
        esac

        # process parsed token
        location="${${(j||)path}//$'\0'}"
        case "${sep[-1]}" in
            "[:}]")
                # token is an object key
                if [[ "${token[1]}" != '"' ]]; then
                    >&2 print "parse error: Object keys must be strings at position ${pos}"
                    return 5
                fi
                # remember object key
                path[-1]=".${${token#\"}%\"}"
                ;;
            "[,}]")
                # token is an object value
                if [[ -z "${selector}" ]]; then
                    # dump location = json value
                    printf '%s=%s\n' "${location}" "${token}"
                elif [[ "${selector}" == "${location}" ]]; then
                    # print selected raw value and return
                    print "${${token#\"}%\"}"
                    return 0
                fi
                ;;
            "[],]")
                # token is a list item
                if [[ -z "${selector}" ]]; then
                    # dump location = json value
                    printf '%s=%s\n' "${location}" "${token}"
                elif [[ "${selector}" == "${location}" ]]; then
                    # print selected raw value and return
                    print "${${token#\"}%\"}"
                    return 0
                fi
                path[-1]=$'\0['"$((${${path[-1]#$'\0['}%]}+1))]"
                ;;
            "")
                # token is a solo value
                location="_[$((obj++))]"
                if [[ -z "${selector}" ]]; then
                    # dump location = json value
                    printf '%s=%s\n' "${location}" "${token}"
                elif [[ "${selector}" == "${location}" ]]; then
                    # print selected raw value and return
                    print "${${token#\"}%\"}"
                    return 0
                fi
                ;;
        esac
        : $((pos+=${#token}-1))

    done

    # return error when no object was parse or selector was not found
    [[ ${obj} -eq 0 || -n "${selector}" ]] && return 4
    return 0

}

_zsh_ai_format_template() {
    local json="$1"
    shift
    if command -v jq &>/dev/null; then
        local args=() arg
        for arg in "$@"; do
            args+=(--arg "${arg%%=*}" "${arg#*=}")
        done
        jq -cMn "${args[@]}" "${json}"
    else
        local arg key value
        for arg in "$@"; do
            key="${arg%%=*}"
            value="$(_zsh_ai_json_strings "${arg#*=}")"
            json="${json//\\\(\$${key}\)/${value:1:-1}}"
        done
        printf "%s\n" "${json}"
    fi
}

# Main query function that routes to the appropriate provider
_zsh_ai_query() {
    local query="$1" response error exit_code

    # Test if provider exists
    if ! command -v "_zsh_ai_query_${ZSH_AI_PROVIDER}" &>/dev/null; then
        print "Error: Invalid provider '${ZSH_AI_PROVIDER}'. Use 'anthropic', 'ollama', 'gemini' or 'openai'."
        return 1
    fi

    # Call check function (if defined)
    if command -v "_zsh_ai_check_${ZSH_AI_PROVIDER}" &>/dev/null; then
        if error="$("_zsh_ai_check_${ZSH_AI_PROVIDER}" "${query}")"; then
            :
        else
            exit_code=$?
            [[ -n "${error}" ]] || error="Error: ${(C)ZSH_AI_PROVIDER} check returned an error: ${exit_code}"
            print -r "${error}"
            return ${exit_code}
        fi
    fi

    # Execute query and normalize response
    if response="$("_zsh_ai_query_${ZSH_AI_PROVIDER}" "${query}")"; then
        :
    else
        exit_code=$?
        [[ -n "${response}" ]] || response="Error: ${(C)ZSH_AI_PROVIDER} query returned an error: ${exit_code}"
        print -r "${response}"
        return ${exit_code}
    fi

    # Remove backticks if in the answer (even though they should not be included)
    response="${${response##[[:space:]]}%%[[:space:]]}"
    if [[ "${response[1,3]}" == '```' && "${response[-3,-1]}" == '```' ]]; then
        response="${${response#*$'\n'}%$'\n'*}"
    elif [[ "${response[1]}" == '`' && "${response[-1]}" == '`' ]]; then
        response="${response[2,-2]}"
    fi
    response="${${response##[[:space:]]}%%[[:space:]]}"
    print -r "${response}"
}

# Optional: Add a helper function for users who prefer explicit commands
zsh-ai() {
    if [[ $# -eq 0 ]]; then
        print 'Usage: zsh-ai "your natural language command"'
        print '\nExample: zsh-ai "find all python files modified today"'
        print "\nCurrent provider: ${ZSH_AI_PROVIDER}"
        local model="ZSH_AI_${(U)ZSH_AI_PROVIDER}_MODEL"
        printf "%-16s: %s\n\n" "${(C)ZSH_AI_PROVIDER} model" "${(P)model}"
        return 1
    fi

    local query="$*"

    # Animation frames - rotating dots (same as widget)
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
        print -n "\r${dots[$((frame++ % ${#dots} + 1))]}"
    done
    while read -rpt 0.1 line; do
        output+=("${line}")
    done

    # Clear the line
    print -n "\r\033[K"

    # Handle response according to exit code
    local cmd="${${${(F)output}##[[:space:]]}%%[[:space:]]}"
    if wait ${pid} && [[ -n "${cmd}" ]]; then
        # Put the command in the ZLE buffer (same as # method)
        print -z "${cmd}"
    else
        # Show error and clear buffer
        print -P "%F{red}Failed to generate command!%f"
        [[ -n "${cmd}" ]] && print "${cmd}"
        return 1
    fi
}
