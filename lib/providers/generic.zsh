#!/usr/bin/env zsh

# Generic API provider for zsh-ai

# Function to call generic API
_zsh_ai_query_generic() {
    [[ $# -lt 6 ]] && {
        print "Error: _zsh_ai_query_generic called with less than 6 arguments!"
        return 1
    }
    local query="$1" model="$2" template="$3" url="$4" response_key="$5" error_key="$6"
    shift 6
    local headers=("$@")
    local response

    # Prepare the JSON payload
    local json_payload="$( \
        _zsh_ai_format_template "${template}" \
        model="${model}" \
        query="${query}" \
        system="$(_zsh_ai_get_system_prompt)" \
    )"

    # Call the API
    response="$(
        curl -s --fail-with-body "${url}" \
        "${(@)headers}" \
        --header "content-type: application/json" \
        --data "${json_payload}" 2>&1
    )" || {
        print "Error: Error when talking to ${(C)ZSH_AI_PROVIDER} API: ${response}"
        return 2
    }
    # Extract the response
    local result="$(_zsh_ai_dump_json "${response}" "${response_key}" 2>/dev/null)"
    if [[ -z "${result}" ]]; then
        # Check for error message
        local error="$(_zsh_ai_dump_json "${response}" "${error_key}" 2>/dev/null)"
        if [[ -n "${error}" ]]; then
            print "API Error: ${error}"
        elif command -v jq &>/dev/null; then
            print "Error: Unable to parse response."
        else
            print "Unable to parse response (install jq for better reliability)"
        fi
        return 3
    fi
    print -r "${result}"
}
