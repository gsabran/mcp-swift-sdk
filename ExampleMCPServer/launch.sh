#!/bin/zsh

dir=$(dirname "$0")
(cd "$dir/.." && swift run ExampleMCPServer -q)