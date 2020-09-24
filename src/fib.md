Formal verification of an iterative Fibonacci calculator.

```act
behaviour fib-loop of Fibber
lemma

// b2 => d4
pc
    178 => 212

for all
    N : uint256
    X : uint256
    Y : uint256
    I : uint256

stack
    I : _ : 0 : Y : X : N : WS => N - 1 : #Fibonacci(N - I, X, Y) : 0 : #Fibonacci(N - I, X, Y) : #Fibonacci(N - I - 1, X, Y) : N : WS

gas
    1 + (615 * (N - 1 - I))

if
    #sizeWordStack(WS) <= 1000
    N > 1
    I < N - 1
```
