#! /bin/env bash

# $1: file extension

nvim ./tests/examples/*$1* -c ":lua require'otter'.dev_setup()"
