#!/bin/bash

python3 -mvenv .venv
source .venv/bin/activate
python main.py >test.sh
chmod +x test.sh
