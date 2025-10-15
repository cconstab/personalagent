#!/bin/bash

# Start Agent Script
# This script ensures the agent runs with the correct working directory and .env file

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🤖 Starting Personal AI Agent...${NC}"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$SCRIPT_DIR/agent"

# Check if agent directory exists
if [ ! -d "$AGENT_DIR" ]; then
    echo -e "${RED}❌ Error: agent directory not found at $AGENT_DIR${NC}"
    exit 1
fi

# Change to agent directory
cd "$AGENT_DIR"
echo -e "${GREEN}📁 Working directory: $(pwd)${NC}"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  Warning: .env file not found${NC}"
    echo -e "${YELLOW}   Checking for .env.example...${NC}"
    
    if [ -f ".env.example" ]; then
        echo -e "${YELLOW}   Found .env.example - creating .env${NC}"
        cp .env.example .env
        echo -e "${GREEN}   ✅ Created .env from .env.example${NC}"
        echo -e "${YELLOW}   ⚠️  Please edit agent/.env with your configuration before continuing${NC}"
        echo ""
        echo -e "   Required settings:"
        echo -e "   - AT_SIGN=@your_agent_atsign"
        echo -e "   - AT_KEYS_FILE_PATH=/path/to/your/keys.atKeys"
        echo -e "   - OLLAMA_HOST=http://localhost:11434"
        echo ""
        exit 1
    else
        echo -e "${RED}❌ Error: No .env or .env.example file found${NC}"
        exit 1
    fi
fi

# Verify required environment variables are set
echo -e "${BLUE}🔍 Checking configuration...${NC}"

# Source the .env file to check variables
set -a  # automatically export all variables
source .env
set +a

ERRORS=0

if [ -z "$AT_SIGN" ]; then
    echo -e "${RED}❌ AT_SIGN not set in .env${NC}"
    ERRORS=$((ERRORS + 1))
fi

if [ -z "$AT_KEYS_FILE_PATH" ]; then
    echo -e "${RED}❌ AT_KEYS_FILE_PATH not set in .env${NC}"
    ERRORS=$((ERRORS + 1))
fi

if [ -n "$AT_KEYS_FILE_PATH" ] && [ ! -f "$AT_KEYS_FILE_PATH" ]; then
    echo -e "${RED}❌ Keys file not found at: $AT_KEYS_FILE_PATH${NC}"
    echo -e "${YELLOW}   You need to onboard your agent @sign first${NC}"
    echo -e "${YELLOW}   See AGENT_SETUP.md for instructions${NC}"
    ERRORS=$((ERRORS + 1))
fi

if [ -z "$OLLAMA_HOST" ]; then
    echo -e "${YELLOW}⚠️  OLLAMA_HOST not set, using default: http://localhost:11434${NC}"
    OLLAMA_HOST="http://localhost:11434"
fi

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo -e "${RED}❌ Configuration errors found. Please fix agent/.env${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Configuration looks good${NC}"
echo -e "${GREEN}   Agent @sign: $AT_SIGN${NC}"
echo -e "${GREEN}   Keys file: $AT_KEYS_FILE_PATH${NC}"
echo -e "${GREEN}   Ollama: $OLLAMA_HOST${NC}"
if [ -n "$CLAUDE_API_KEY" ]; then
    echo -e "${GREEN}   Claude: enabled${NC}"
fi
echo ""

# Check if Ollama is running
echo -e "${BLUE}🔍 Checking Ollama availability...${NC}"
if curl -s "$OLLAMA_HOST" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Ollama is running at $OLLAMA_HOST${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: Ollama doesn't appear to be running at $OLLAMA_HOST${NC}"
    echo -e "${YELLOW}   The agent will start but may fail to process queries${NC}"
    echo -e "${YELLOW}   Start Ollama with: ollama serve${NC}"
    echo ""
fi

# Start the agent
echo -e "${BLUE}🚀 Starting agent...${NC}"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Run the agent with explicit .env path
dart run bin/agent.dart --env .env

# If the agent exits, show a message
echo ""
echo -e "${YELLOW}Agent stopped${NC}"
