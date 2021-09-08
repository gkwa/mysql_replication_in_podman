#!/bin/bash

python3 -mvenv .venv
source .venv/bin/activate
pip install jinja2 pyyaml
python main.py >test.sh
chmod +x test.sh
