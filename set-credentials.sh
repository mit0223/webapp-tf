#!/bin/bash
aws configure set --profile default-long-term aws_access_key_id $LONG_TERM_ACCESS_KEY_ID
aws configure set --profile default-long-term aws_secret_access_key $LONG_TERM_SECRET_ACCESS_KEY
