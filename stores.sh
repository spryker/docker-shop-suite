#!/bin/bash 

#Parse string STORES to the array of country names STORE
IFS=',' read -ra STORE <<< "$STORES"
for i in "${STORE[@]}"; do
    export XX=$i
    export xx=$(echo $i | tr [A-Z] [a-z])
    echo $XX
    echo $xx
done



#while IFS=',' read -ra ADDR; do
#      for i in "${ADDR[@]}"; do
#          echo $i
#      done
#done <<< "$STORES"
