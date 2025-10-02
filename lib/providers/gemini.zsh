#!/usr/bin/env zsh

# Google Gemini API provider for zsh-ai

# Function to check Gemini config
_zsh_ai_check_gemini() {
    [[ -n "${GEMINI_API_KEY}" ]] || {
        print "Error: GEMINI_API_KEY not set"
        return 1
    }
}

# Function to call Gemini API
_zsh_ai_query_gemini() {
    _zsh_ai_query_generic \
        "$1" \
        "" \
        '{
            "contents": [
                {
                    "role": "user",
                    "parts": [{"text": "\($query)"}]
                }
            ],
            "systemInstruction": {
                "parts": [{"text": "\($system)"}]
            },
            "generationConfig": {
                "temperature": 0.3,
                "maxOutputTokens": 256,
                "thinkingConfig": {
                    "thinkingBudget": 0
                }
            }
        }' \
        "https://generativelanguage.googleapis.com/v1beta/models/${ZSH_AI_GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}" \
        '.candidates[0].content.parts[0].text' \
        '.error.message'
}
