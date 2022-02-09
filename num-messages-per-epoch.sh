#!/bin/bash
for i in $(seq 1 11); do echo -n "$i:"; git -C ../lkml/$i rev-list HEAD --count; done | tee num-messages-per-epoch.txt
