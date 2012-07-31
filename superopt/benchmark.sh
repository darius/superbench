#!/bin/sh
# Produce benchmark timings of different implementations of the same
# circuitoptimizer program, into time-* files. (Outputs in out-*.)

timex=`which time`  # To avoid shell builtin that won't redirect output

args="01100111 6"
#args="01100100 7"
#args="01101011 8"

csc compiled_circuitoptimizer.scm
gcc -Wall -Wmissing-prototypes -Wstrict-prototypes -pedantic -ansi -std=c99 -g2 -O2 circuitoptimizer.c -o circuitoptimizer

echo C
>out-c 2>time-c
for trial in 1 2 3; do
    echo trial $trial
    $timex ./circuitoptimizer $args >>out-c 2>>time-c
done

echo chickencompiled
>out-chickencompiled 2>time-chickencompiled
for trial in 1 2 3; do
    echo trial $trial
    $timex ./compiled_circuitoptimizer $args >>out-chickencompiled 2>>time-chickencompiled
done

echo luajit
>out-luajit 2>time-luajit
for trial in 1 2 3; do
    echo trial $trial
    $timex luajit circuitoptimizer.lua $args >>out-luajit 2>>time-luajit
done

echo python
>out-python 2>time-python
for trial in 1; do
    echo trial $trial
    $timex python circuitoptimizer.py $args >>out-python 2>>time-python
done

# TO DO
# add mlton & bummed versions
