#!/usr/bin/env zsh

# Configuration and validation for zsh-ai

# Set default values for configuration
: ${ZSH_AI_GUARD:=""} # Guard string a comment needs to start with to trigger zsh ai
: ${ZSH_AI_PROVIDER:="anthropic"}  # Default to anthropic for backwards compatibility
: ${ZSH_AI_OLLAMA_MODEL:="llama3.2"}  # Popular fast model
: ${ZSH_AI_OLLAMA_URL:="http://localhost:11434"}  # Default Ollama URL
: ${ZSH_AI_GEMINI_MODEL:="gemini-2.5-flash"}  # Fast Gemini 2.5 model
: ${ZSH_AI_OPENAI_MODEL:="gpt-4o"}  # Default to GPT-4o
: ${ZSH_AI_OPENAI_URL:="https://api.openai.com"} # Default OpenAI URL
: ${ZSH_AI_ANTHROPIC_MODEL:="claude-3-5-sonnet-20241022"}  # Default Anthropic model

# Optional: Extend the system prompt with custom instructions
# ZSH_AI_PROMPT_EXTEND - Add custom instructions to the AI prompt without replacing the core prompt
# Example: export ZSH_AI_PROMPT_EXTEND="Always prefer ripgrep (rg) over grep. Use modern CLI tools when available."

# Provider validation
_zsh_ai_validate_config() {
    # Check requirements based on provider
    case "${ZSH_AI_PROVIDER}" in
        "anthropic")
            [[ -n "${ANTHROPIC_API_KEY}" ]] || {
                print "zsh-ai: Warning: ANTHROPIC_API_KEY not set. Plugin will not function."
                print "zsh-ai: Set ANTHROPIC_API_KEY or use ZSH_AI_PROVIDER=ollama for local models."
                return 1
            };;
        "ollama")
            ;;
        "gemini")
            [[ -n "${GEMINI_API_KEY}" ]] || {
                print "zsh-ai: Warning: GEMINI_API_KEY not set. Plugin will not function."
                print "zsh-ai: Set GEMINI_API_KEY or use ZSH_AI_PROVIDER=ollama for local models."
                return 1
            };;
        "openai")
            [[ -n "${OPENAI_API_KEY}" ]] || {
                print "zsh-ai: Warning: OPENAI_API_KEY not set. Plugin will not function."
                print "zsh-ai: Set OPENAI_API_KEY or use ZSH_AI_PROVIDER=ollama for local models."
                return 1
            };;
        *)
            print "zsh-ai: Error: Invalid provider '${ZSH_AI_PROVIDER}'. Use 'anthropic', 'ollama', 'gemini', or 'openai'."
            return 1;;
    esac
    return 0
}
