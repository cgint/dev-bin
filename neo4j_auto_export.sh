#!/bin/bash
# Auto-export all running Neo4j containers using neo4j_export_py.py
# Detects running Neo4j containers, finds their Bolt port, and runs the export script for each

set -euo pipefail

EXPORT_SCRIPT="neo4j_export_structured.py"
DEFAULT_USERNAME="neo4j"
DEFAULT_PASSWORD="demodemo"
AUTO_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -a|--auto)
      AUTO_MODE=true
      shift
      ;;
    *)
      echo "Usage: $0 [-a|--auto]"
      echo "  -a, --auto: Export all containers without interactive selection"
      exit 1
      ;;
  esac
done

if ! [ -f "$EXPORT_SCRIPT" ]; then
  echo "❌ $EXPORT_SCRIPT not found in current directory."
  exit 1
fi

# Find all running Neo4j containers
containers=$(docker ps --format '{{.Names}}\t{{.Image}}' | grep -i 'neo4j' | cut -f1)

if [ -z "$containers" ]; then
  echo "No running Neo4j containers found."
  exit 0
fi

echo "Found Neo4j containers:"
echo "$containers"

# Use parallel arrays for names and ports
container_names=()
container_ports=()

echo ""
echo "Detecting Bolt ports..."
for cname in $containers; do
  port=$(docker inspect -f '{{range $p, $conf := .NetworkSettings.Ports}}{{if eq $p "7687/tcp"}}{{(index $conf 0).HostPort}}{{end}}{{end}}' "$cname")
  if [ -z "$port" ]; then
    echo "⚠️  Could not find Bolt port for $cname, skipping."
    continue
  fi
  container_names+=("$cname")
  container_ports+=("$port")
  echo "  $cname: bolt://localhost:$port"
done

if [ ${#container_names[@]} -eq 0 ]; then
  echo "❌ No Neo4j containers with accessible Bolt ports found."
  exit 1
fi

# Interactive selection unless auto mode
selected_indices=()
if [ "$AUTO_MODE" = true ]; then
  echo ""
  echo "🚀 Auto mode: exporting all containers..."
  for i in "${!container_names[@]}"; do
    selected_indices+=("$i")
  done
else
  echo ""
  echo "Select containers to export:"
  for i in "${!container_names[@]}"; do
    echo "  $((i+1)). ${container_names[$i]} (bolt://localhost:${container_ports[$i]})"
  done
  echo "  a. All containers"
  echo ""
  
  while true; do
    read -p "Enter your choice (numbers separated by spaces, or 'a' for all): " choice
    
    if [[ "$choice" == "a" ]]; then
      for i in "${!container_names[@]}"; do
        selected_indices+=("$i")
      done
      break
    else
      # Parse individual numbers
      valid=true
      temp_indices=()
      for num in $choice; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#container_names[@]} ]; then
          temp_indices+=($((num-1)))
        else
          echo "❌ Invalid choice: $num. Please enter numbers between 1 and ${#container_names[@]}, or 'a' for all."
          valid=false
          break
        fi
      done
      
      if [ "$valid" = true ]; then
        selected_indices=("${temp_indices[@]}")
        break
      fi
    fi
  done
fi

# Export data for selected containers
for i in "${selected_indices[@]}"; do
  cname="${container_names[$i]}"
  port="${container_ports[$i]}"
  
  # Use default credentials automatically and specify the export directory
  uv run "$EXPORT_SCRIPT" --uri "bolt://localhost:$port" --username "$DEFAULT_USERNAME" --password "$DEFAULT_PASSWORD"
done

echo ""
echo "✅ All exports complete." 