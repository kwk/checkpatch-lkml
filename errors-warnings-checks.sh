#!/bin/bash
grep -oP '(ERROR|WARNING|CHECK):[A-Z_]+:' checkpatch-results/ -r -h | sort | uniq -c | sort -nr > errors-warnings-checks.txt
