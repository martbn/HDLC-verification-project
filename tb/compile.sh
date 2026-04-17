#!/usr/bin/env bash

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$SCRIPT_DIR"

rm -rf work*

RED='\033[0;31m'
NC='\033[0m'    

vlib work 

printf "${RED}\nCompiling design${NC}\n"
if vlog -sv ../rtl/*.sv 
then
	echo "Success"
else
	echo "Failure"
	exit 1
fi

printf "${RED}\nCompiling test files${NC}\n"
if vlog -sv +incdir+. \
  ./in_hdlc.sv \
  ./testPr_hdlc.sv \
  ./test_hdlc.sv \
  ./assertions_hdlc.sv \
  ./bind_hdlc.sv
then
	echo "Success"
else
	echo "Failure"
	exit 1
fi
