#! /bin/env bash
# usage: ./tests/debug-example.sh $1

echo "choose an example file based on number of extension."
echo "e.g. ./tests/debug-example.sh 01"
echo "e.g. ./tests/debug-example.sh qmd"
echo "Options"
ls ./tests/examples/

if [ -z "$1" ]; then
  echo "Please provide a file extension or a number"
  echo "And call this from the project root directory"
  exit 1
fi

# open split and navigate back to the first window
nvim ./tests/examples/*$1* -c ":lua require'otter'.activate()" -c ':vsplit' -c ':b2' -c ':wincmd w'
