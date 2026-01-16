#!/bin/bash

stage_setup() {
git init -q
  mkdir -p src api docs .gemini

  echo 'package main; import "github.com/gin-gonic/gin"; func main() { r := gin.Default(); r.Run() }' > api/server.go
  echo -e "module senior-app/api\n\ngo 1.21" > api/go.mod

  echo '{"name": "senior-app", "version": "1.0.0", "scripts": {"build": "webpack"}}' > package.json

  echo 'import pandas as pd; print("Data Analysis Mode")' > src/main.py
  
  echo "# Setup\nRun 'make install' to begin." > docs/setup.md

  cat <<'EOF' > MISSION.md
# MISSION: ARCHITECTURAL SCOUT
Your goal is to analyze this repository and identify the tech stack.

## REQUIRED ACTION
1. Scan the codebase using basic shell commands (ls, cat, find, grep).
2. **CREATE** the directory `.gemini` if it doesn't exist (run `mkdir -p .gemini`).
3. Generate a summary report analyzing the frameworks and languages found.
4. **SAVE** the report to `.gemini/scout_report.md`.

## TECH STACK TO DETECT
- Look for: Gin (Go), Pandas (Python), Webpack (Node.js)
- Check file extensions: .go, .py, .js, .json
- Examine manifest files: go.mod, package.json

## SUCCESS CRITERIA
- The file `.gemini/scout_report.md` MUST exist after execution.
- The report MUST mention the specific frameworks found (Gin, Pandas, Webpack, Go 1.21).
- Use simple file writing: `mkdir -p .gemini && cat > .gemini/scout_report.md << 'EOF'`

## CONSTRAINTS
- DO NOT use "skills" or advanced tool activations.
- ONLY use basic shell commands.
- Ensure the `.gemini` directory exists before writing the report.
EOF

git add . && git commit -m "initial project structure" -q
}

stage_verify() {
  local log_file=$1
  local report_file=".gemini/scout_report.md"
  
  if [ ! -f "$report_file" ]; then
    echo -e "${GREY}│${NC} ${RED}✗${NC} ${WHITE}Failure:${NC} No report file found at $report_file"
    return 1
  fi

  local tech_stack=$(grep -Ei "Gin|Pandas|Webpack|Go 1.21" "$report_file" | xargs)
  local file_size=$(du -h "$report_file" | cut -f1)
  
  echo -e "${GREY}│${NC} ${CYAN}i${NC} ${WHITE}Report Artifact:${NC}"
  echo -e "${GREY}│${NC}   Size: ${GREY}${file_size}${NC}"
  echo -e "${GREY}│${NC}   Stack: ${YELLOW}${tech_stack:-None}${NC}"
  
  if [ -n "$tech_stack" ]; then
    return 0
  fi
  
  echo -e "${GREY}│${NC} ${RED}✗${NC} Report existed but missed key tech stack details."
  return 1
}