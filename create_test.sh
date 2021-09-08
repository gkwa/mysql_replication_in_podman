#!/bin/bash

python3 -mvenv .venv
source .venv/bin/activate
pip install -r requirements.txt
python main.py >test.sh
chmod +x test.sh
