requires "data.md"
requires "edsl.md"

requires "../../deps/evm-semantics/tests/specs/infinite-gas.k"

requires "../bin_runtime.k"

module VERIFICATION-SYNTAX
    imports EDSL
    imports EVM-DATA
    imports INFINITE-GAS
    imports BIN_RUNTIME

    syntax Bool ::= #notPrecompileAddress ( Int ) [function]
 // --------------------------------------------------------
    rule #notPrecompileAddress ( X ) => 0 ==Int X orBool (10 <=Int X andBool #rangeAddress(X))

endmodule

module VERIFICATION
    imports VERIFICATION-SYNTAX

    // Fibonacci lemmas
    syntax Int ::= "#Fibonacci" "(" Int "," Int "," Int ")" [function]

    rule #Fibonacci( 0 , X , Y ) => X

    rule #Fibonacci( 1 , X , Y ) => Y

    rule #Fibonacci( N , X , Y ) => #Fibonacci( N -Int 1 , Y , X +Int Y )
        requires N >Int 1

endmodule
