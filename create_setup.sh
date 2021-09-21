#!/bin/bash

python3 -mvenv .venv
source .venv/bin/activate
pip install -r requirements.txt >/dev/null
python main.py
chmod +x setup.sh
