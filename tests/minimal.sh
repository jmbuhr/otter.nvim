#!/usr/bin/env bash

# Usage:
# execute ./minimal.sh twice.
#
# The first time Lazy and Mason will
# install the required plugins and the lua language server.
# The second time the provided minimal.md file should
# be open and ready with code completion and e.g.
# got to definition, K hover etc.

export NVIM_APPNAME='otter-repro'
nvim -u minimal.lua ./examples/minimal.md -c ':lua require"otter".activate()'
