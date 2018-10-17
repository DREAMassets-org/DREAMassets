#!/bin/bash

cd sobun

source venv/bin/activate
pip install -r requirements.txt

python -m dream.batcher --reset
