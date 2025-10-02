#!/usr/bin/env zsh

# Anthropic Claude API provider for zsh-ai

# Function to check Anthropic config
_zsh_ai_check_anthropic() {
    [[ -n "${ANTHROPIC_API_KEY}" ]] || {
        print "Error: ANTHROPIC_API_KEY not set"
        return 1
    }
}

# Function to call Anthropic API
_zsh_ai_query_anthropic() {
    _zsh_ai_query_generic \
        "$1" \
        "${ZSH_AI_ANTHROPIC_MODEL}" \
        '{
            "model": "\($model)",
            "max_tokens": 256,
            "system": "\($system)",
            "messages": [
                {
                    "role": "user",
                    "content": "\($query)"
                }
            ]
        }' \
        "https://api.anthropic.com/v1/messages" \
        '.content[0].text' \
        .error.message \
        --header "x-api-key: ${ANTHROPIC_API_KEY}" \
        --header "anthropic-version: 2023-06-01"
}
