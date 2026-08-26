#!/usr/bin/env bash

# Install all skills from the major repositories globally
npx skills add aniruddhaadak80/skills --skill '*' --yes --global
npx skills add langchain-ai/langchain-skills --skill '*' --yes --global
npx skills add lbk-open/super-spec --skill '*' --yes --global
npx skills add grahama1970/agent-skills --skill '*' --yes --global

# Install Praetor (18 agents + 4-judge council)
npx praetor-audit-kit --install

