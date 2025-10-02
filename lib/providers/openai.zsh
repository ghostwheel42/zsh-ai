#!/usr/bin/env zsh

# OpenAI API provider for zsh-ai

# Function to check OpenAI config
_zsh_ai_check_openai() {
    [[ -n "${OPENAI_API_KEY}" ]] || {
        print "Error: OPENAI_API_KEY not set"
        return 1
    }
}

# Function to call OpenAI API
_zsh_ai_query_openai() {
    _zsh_ai_query_generic \
        "$1" \
        "${ZSH_AI_OPENAI_MODEL}" \
        '{
            "model": "\($model)",
            "messages": [
                {
                    "role": "system",
                    "content": "\($system)"
                },
                {
                    "role": "user",
                    "content": "\($query)"
                }
            ],
            "max_tokens": 256,
            "temperature": 0.3
        }' \
        "${ZSH_AI_OPENAI_URL}/v1/chat/completions" \
        '.choices[0].message.content' \
        '.error.message' \
        --header "Authorization: Bearer ${OPENAI_API_KEY}"
}
