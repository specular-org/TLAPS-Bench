#!/bin/bash
set -e
# 1.0.115 and 1.0.116 write no OTel usage file for BYOK runs without a GitHub sign-in.
npm install -g @github/copilot@1.0.114 --cache /tmp/.npm && rm -rf /tmp/.npm
