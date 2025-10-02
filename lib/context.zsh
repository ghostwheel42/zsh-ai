#!/usr/bin/env zsh

# Context detection functions for zsh-ai

# Function to detect project type
_zsh_ai_detect_project_type() {
    local project_type=""
    if [[ -f "package.json" ]]; then
        project_type="node"
    elif [[ -f "Cargo.toml" ]]; then
        project_type="rust"
    elif [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]]; then
        project_type="python"
    elif [[ -f "Gemfile" ]]; then
        project_type="ruby"
    elif [[ -f "go.mod" ]]; then
        project_type="go"
    elif [[ -f "composer.json" ]]; then
        project_type="php"
    elif [[ -f "pom.xml" ]] || [[ -f "build.gradle" ]]; then
        project_type="java"
    elif [[ -f "docker-compose.yml" ]] || [[ -f "Dockerfile" ]]; then
        project_type="docker"
    fi
    [[ -n "${project_type}" ]] && print -r "Project type: ${project_type}"
}

# Function to get git context
_zsh_ai_get_git_context() {
    git rev-parse --is-inside-work-tree &>/dev/null || return 0

    local branch="$(git branch --show-current 2>/dev/null)"
    local git_status="clean"
    [[ -n $(git status --porcelain 2>/dev/null) ]] && git_status="dirty"

    print -r "Git: branch=${branch}, status=${git_status}"
}

# Function to get directory context (file count and up to 10 names of non-hidden files)
_zsh_ai_get_directory_context() {

    print -r "Current directory: $(_zsh_ai_json_strings "${PWD}")"
    local names
    for what in ".Files" "/Directories"; do
        names=()
        printf -v names "%q" *(${what[1]}omN)
        print -rn "${what#?} as JSON list: $(_zsh_ai_json_strings "${(@)names[1,10]}")"
        [[ ${#names} -gt 10 ]] && print -n " and $((${#names}-10)) more."
        print
    done

}

# Function to build context
_zsh_ai_build_context() {

    # Add directory context
    _zsh_ai_get_directory_context

    # Add project type
    _zsh_ai_detect_project_type

    # Add git context
    _zsh_ai_get_git_context

    # Add OS context
    print -r "OS: $(_zsh_ai_json_strings "$(uname -s)")"
    print -r "User: $(_zsh_ai_json_strings "${USER}")"
}
