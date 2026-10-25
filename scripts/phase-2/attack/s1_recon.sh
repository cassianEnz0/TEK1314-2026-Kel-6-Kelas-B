#!/bin/bash
# S1 - Reconnaissance & service enumeration
TARGET="${1:-172.16.6.10}"
echo "==================================================="
echo " S1  RECONNAISSANCE  ->  $TARGET"
echo "==================================================="
nmap -Pn -sV -T4 -p 22,3000,4000,5432,6543,8000,8443,9999 "$TARGET"
