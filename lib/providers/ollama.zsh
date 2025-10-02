#!/usr/bin/env zsh

# Ollama API provider for zsh-ai

# Function to check if Ollama is running
_zsh_ai_check_ollama() {
    curl -sm 1 "${ZSH_AI_OLLAMA_URL}/api/tags" &>/dev/null && return 0
    local exit_code=$?
    print "Error: Ollama is not running at ${ZSH_AI_OLLAMA_URL}"
    print "Start Ollama with: ollama serve"
    return ${exit_code}

}

# Function to call Ollama API
_zsh_ai_query_ollama() {
    _zsh_ai_query_generic \
        "$1" \
        "${ZSH_AI_OLLAMA_MODEL}" \
        '{
            "model": "\($model)",
            "prompt": "\($query)",
            "system": "\($system)",
            "stream": false,
            "think": false,
            "options": {
                "temperature": 0.3
            }
        }' \
        "${ZSH_AI_OLLAMA_URL}/api/generate" \
        .response \
        .error
    local exit_code=$?
    [[ ${exit_code} -eq 2 ]] && print "Is it running?"
    return ${exit_code}
}
