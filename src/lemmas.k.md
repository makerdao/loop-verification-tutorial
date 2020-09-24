# Define lemmas needed for proving here

```k
syntax Int ::= "#Fibonacci" "(" Int "," Int "," Int ")" [function]

rule #Fibonacci( 0 , X , Y ) => X

rule #Fibonacci( 1 , X , Y ) => Y

rule #Fibonacci( N , X , Y ) => #Fibonacci( N - 1 , Y , X + Y )
    requires N >Int 1
```
