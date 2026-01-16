#!/bin/bash

EXPECTED_PATTERN="gh pr create"
REMOTE_URL="git@github.com:erclx/dot-gemini-sandbox.git"

stage_setup() {
git init -q
git remote add origin "$REMOTE_URL"
git config user.email "architect@erclx.com"
git config user.name "Senior Architect"

git push origin --delete feature/string-utils -q 2>/dev/null || true

echo "console.log('App Started')" > index.js
echo "# Core Utils" > README.md
git add . && git commit -m "chore: init" -q
git push origin main --force -q

  git checkout -b feature/string-utils -q

  cat <<'EOF' > utils.js
export function slugify(text) {
  return text.toString().toLowerCase().replace(/\s+/g, '-');
}
EOF

git add . && git commit -m "feat: add slugify helper" -q
  
  git push origin feature/string-utils -q
  
  echo -e "${GREEN}✓${NC} Feature branch pushed: feature/string-utils"
}

stage_verify() {
  local log_file=$1
  
  if grep -iq "gh pr create" "$log_file"; then
    echo -e "${GREY}│${NC} ${GREEN}✓${NC} ${WHITE}Detected CLI command execution.${NC}"
    return 0
  fi

  local pr_url=$(grep -Eo "https://github.com/.*/pull/[0-9]+" "$log_file" | head -n 1)
  if [ -n "$pr_url" ]; then
    echo -e "${GREY}│${NC} ${CYAN}i${NC} ${WHITE}Verified Created PR:${NC} ${CYAN}${pr_url}${NC}"
    return 0
  fi
  
  if grep -iq "/compare/" "$log_file"; then
     echo -e "${GREY}│${NC} ${RED}✗${NC} ${YELLOW}AI took a shortcut (Compare Link).${NC}"
  fi

  return 1
}