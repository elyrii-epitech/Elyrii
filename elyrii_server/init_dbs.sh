#!/bin/bash
set -e

# Function to create database if it doesn't exist
create_database() {
  local database=$1
  echo "Checking if database '$database' exists..."
  if psql -U "$POSTGRES_USER" -lqt | cut -d \| -f 1 | grep -qw "$database"; then
    echo "Database '$database' already exists. Skipping."
  else
    echo "Creating database '$database'..."
    psql -U "$POSTGRES_USER" -c "CREATE DATABASE $database"
  fi
}

# Create the required databases
create_database "elyrii_db"
