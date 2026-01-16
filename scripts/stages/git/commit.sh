#!/bin/bash

EXPECTED_PATTERN="^(fix|refactor|perf|chore|feat)(\(.*\))?: .+"

stage_setup() {
git init -q
git config user.email "architect@erclx.com"
git config user.name "Senior Architect"

echo 'export const MAX_CONNECTIONS = "5";' > config.js
git add . && git commit -m "feat: initial config" -q

echo 'export const MAX_CONNECTIONS = 5;' > config.js
git add config.js
}

stage_verify() {
  local log_file=$1
  local last_commit=$(git log -1 --pretty=%B 2>/dev/null || true)
  local last_hash=$(git rev-parse --short HEAD 2>/dev/null || true)

  echo -e "${GREY}│${NC} ${CYAN}i${NC} ${WHITE}Verification Data:${NC}"
  echo -e "${GREY}│${NC}   Hash: ${GREY}${last_hash}${NC}"
  echo -e "${GREY}│${NC}   Msg:  ${YELLOW}${last_commit}${NC}"
  
  if echo "$last_commit" | grep -Eiq "$EXPECTED_PATTERN"; then
    return 0
  fi

  if grep -Eiq "$EXPECTED_PATTERN" "$log_file"; then
    echo -e "${GREY}│${NC} ${YELLOW}!${NC} Found pattern in AI logs, but not in Git history."
    return 0
  fi

  return 1
}