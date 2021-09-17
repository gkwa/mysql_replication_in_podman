#!/bin/bash

python3 -mvenv .venv
source .venv/bin/activate
pip install -r requirements.txt >/dev/null
python main2.py
chmod +x test.sh
