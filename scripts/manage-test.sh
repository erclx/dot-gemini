#!/bin/bash
set -e
set -o pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
WHITE='\033[1;37m'
GREY='\033[0;90m'
NC='\033[0m'

log_info()  { echo -e "${GREY}│${NC} ${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "${GREY}│${NC} ${YELLOW}!${NC} $1"; }
log_error() { echo -e "${GREY}│${NC} ${RED}✗${NC} $1"; exit 1; }
log_step()  { echo -e "${GREY}│${NC}\n${GREY}├${NC} ${WHITE}$1${NC}"; }

show_help() {
  echo -e "${GREY}┌${NC}"
  log_step "Gemini Extension Orchestrator Help"
  echo -e "${GREY}│${NC}  ${WHITE}Usage:${NC}"
  echo -e "${GREY}│${NC}    gtest              ${GREY}# Open interactive picker${NC}"
  echo -e "${GREY}│${NC}    gtest <cat>:<cmd>  ${GREY}# Stage a specific environment${NC}"
  echo -e "${GREY}│${NC}    gtest test <args>  ${GREY}# Run automated E2E test${NC}"
  echo -e "${GREY}│${NC}    gtest clean        ${GREY}# Wipe the sandbox${NC}"
  echo -e "${GREY}│${NC}"
  echo -e "${GREY}│${NC}  ${WHITE}Examples:${NC}"
  echo -e "${GREY}│${NC}    gtest git:commit"
  echo -e "${GREY}│${NC}    gtest test git:pr"
  echo -e "${GREY}└${NC}"
  exit 0
}

select_option() {
  local prompt_text=$1
  shift
  local options=("$@")
  local cur=0
  local count=${#options[@]}
  echo -e "${GREY}│${NC}"
  echo -ne "${GREEN}◆${NC} ${prompt_text}\n"
  while true; do
    for i in "${!options[@]}"; do
      if [ $i -eq $cur ]; then
        echo -e "${GREY}│${NC}  ${GREEN}❯ ${options[$i]}${NC}"
      else
        echo -e "${GREY}│${NC}    ${GREY}${options[$i]}${NC}"
      fi
    done
    read -rsn1 key
    case "$key" in
      $'\x1b')
        read -rsn2 key
        if [[ "$key" == "[A" ]]; then cur=$(( (cur - 1 + count) % count )); fi
        if [[ "$key" == "[B" ]]; then cur=$(( (cur + 1) % count )); fi
        ;;
      "k") cur=$(( (cur - 1 + count) % count ));;
      "j") cur=$(( (cur + 1) % count ));;
      "") break ;;
    esac
    echo -ne "\033[${count}A"
  done
  echo -ne "\033[1A\r\033[K\r\033[${count}A\r\033[K"
  echo -e "${GREY}◇${NC} ${prompt_text} ${WHITE}${options[$cur]}${NC}"
  export SELECTED_OPT="${options[$cur]}"
}

setup_ssh() {
  log_step "Security Authentication"
  if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
    ssh-add ~/.ssh/id_rsa
    log_info "SSH Agent initialized"
  else
    log_info "SSH Agent active"
  fi
}

main() {
  local SANDBOX="./.sandbox"
  local STAGES_DIR="./scripts/stages"
  local NAMESPACE="erclx-core"
  local MODE="stage"
  local LLM_MODEL="gemini-2.5-flash"    
  local YOLO_FLAG="--yolo" 

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
  fi

  echo -e "${GREY}┌${NC}"

  if [[ "$1" == "test" ]]; then
    MODE="test"
    shift
  fi

  if [ -z "$1" ]; then
    local categories=($(ls -d "$STAGES_DIR"/*/ | xargs -n1 basename))
    select_option "Select category:" "${categories[@]}"
    local category=$SELECTED_OPT
    local commands=($(ls "$STAGES_DIR/$category/"*.sh | xargs -n1 basename | sed 's/\.sh//'))
    select_option "Select command:" "${commands[@]}"
    local command=$SELECTED_OPT
  else
    if [ "$1" == "clean" ]; then
      rm -rf "$SANDBOX" && log_info "Cleaned." && echo -e "${GREY}└${NC}" && exit 0
    fi
    
    if [[ "$1" != *":"* ]]; then
      log_error "Invalid format. Use <category>:<command> or --help"
    fi

    IFS=':' read -r category command <<< "$1"
  fi

  local stage_file="$STAGES_DIR/$category/$command.sh"
  
  if [ ! -f "$stage_file" ]; then
    log_error "Stage script not found: $category/$command"
  fi

  source "$stage_file"

  [ "$category" == "git" ] && [ "$command" == "pr" ] && setup_ssh

  log_step "Provisioning $category:$command"
  rm -rf "$SANDBOX" && mkdir -p "$SANDBOX"
  
  cat <<EOF > "$SANDBOX/.gitignore"
.test_log
EOF

  (cd "$SANDBOX" && stage_setup)
  log_info "Sandbox ready"

  if [[ "$MODE" == "test" ]]; then
    log_step "Auto-Testing /$NAMESPACE.$category:$command"
    cd "$SANDBOX"
    gemini --model "$LLM_MODEL" $YOLO_FLAG "/$NAMESPACE.$category:$command" | tee .test_log
    
    log_step "Validation"
    if stage_verify ".test_log"; then
      log_info "Assertion Passed: Verification Hook Succeeded"
    else
      log_error "Assertion Failed: Stage verification failed"
    fi
  fi

  echo -e "${GREY}└${NC}\n"
  [ "$MODE" == "stage" ] && echo -e "${GREEN}✓ Ready: ${WHITE}cd $SANDBOX && gemini /$NAMESPACE.$category:$command${NC}"
  [ "$MODE" == "test" ] && echo -e "${GREEN}✓ Auto-test complete${NC}"
}

main "$@"