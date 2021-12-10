        .text
        .global _start
_start: 
setup:
        stmfd   sp!, {r4, lr}        // save registers
        mov     r4, #0               // going to use r4 as the number of items in the stack
        ldr     r0, =welcome_txt
        bl      puts

prompt: 
        ldr     r0, =prompt_txt      // prompt for input
        bl      printf

get_input:
        ldr     r0, =str_in          // get user input
        ldr     r1, =str_size
        ldr     r2, =stdin
        ldr     r2, [r2]
        bl      fgets
        cmp     r0, #0               // check for EOF error - can test with ctrl+d (EOF)
        BEQ     error_fgets          // ERROR - no input data!
        bl      strlen               
        cmp     r0, #1               // check input.len > 1 to ensure more data than just '\n'
        BLE     error_fgets          // Error - only '\n'
        ldr     r1, =str_size
        sub     r1, r1, #1
        cmp     r1, r0
        BEQ     error_max_in         // Error - string exceeds max length of buffer
        sub     r1, r0, #1
        ldr     r0, =str_in
        mov     r2, #0
        strb    r2, [r0, r1]         // remove trailing '\n' from str_in

handle_input:
        ldr     r1, =float_in        // scan existing str_in for NUMBER -- pointer to str_in should already be in r0 from previous section
        sub     sp, sp, #8
        mov     r2, sp
        ldr     r3, =dummy_str
        bl      sscanf               
        cmp     r0, #1
        addeq   r4, r4, #8
        BEQ     prompt               // if only 1 value (number) was filled, push to stack, and go back to prompt
        add     sp, sp, #8
        ldr     r0, =str_in          // else, check to see if input.len == 1 to see if it some other operator
        bl      strlen
        cmp     r0, #1
        BNE     error_input          // ERROR - already know str does not contain a number, input contains more than 1 character and is now erroneous.
        
        LDR     r0, =str_in
        LDRB    r0, [r0]             // grab first char of input in order to check for operator

compare_to_ops:
        cmp     r0, #'a'             // compare to 'a', if r0 >= 'a' perform misc test, otherwise perform operator test
        BGE     misc_test
operator_test:                       // +, -, *, /, ^, !, L (logb(a)), S (sin), C (cos), T (tan), E (eulers), P (pi)
        mov     r1, #2               // number of operands -- used in math functions
        cmp     r0, #'+'
        BEQ     math
        cmp     r0, #'-'
        BEQ     math
        cmp     r0, #'*'
        BEQ     math
        cmp     r0, #'\/'
        BEQ     math
        cmp     r0, #'^'
        BEQ     math
        cmp     r0, #'L'
        BEQ     math

        mov     r1, #1               // only 1 operand used below
        cmp     r0, #'!'
        BEQ     math
        cmp     r0, #'S'
        BEQ     math
        cmp     r0, #'C'
        BEQ     math
        cmp     r0, #'T'
        BEQ     math

        cmp     r0, #'E'             // push  e = 2.718281828459045
        vldreq.f64  d0, =0x4005bf0a8b145769
        vpusheq {d0}
        addeq   r4, r4, #8
        BEQ     prompt
        cmp     r0, #'P' 
        vldreq.f64  d0, =0x400921fb54442d18
        vpusheq {d0}
        addeq   r4, r4, #8
        BEQ     prompt               // push pi = 3.141592653589793
        b       error_operator       // ERROR: no match

misc_test:                           // h, q, c, z, p
        cmp     r0, #'h'             // print manpage
        ldreq   r0, =man
        bleq    puts
        BEQ     prompt

        cmp     r0, #'q'             // exit
        BEQ     quit

        cmp     r0, #'c'
        addeq   sp, sp, r4           // clear stack and reset r4
        moveq   r4, #0
        BEQ     prompt

        cmp     r0, #'z'
        addeq   sp, sp, #8           // clear stack and reset r4
        subeq   r4, r4, #8
        BEQ     prompt

        cmp     r0, #'p'
        BlEQ    print_stack
        BEQ     prompt
  
        b       error_misc           // ERROR: no match

print_stack:
        push    {r5, lr}             // tmp stack counter, but do not increment when pushing r5 and lr
        ldr     r0, =stack_print_str
        bl      printf
        movs    r5, r4
        popeq   {r5, lr}
        BEQ     prompt
pr_lp:  ldr     r0, =looping_out
        ldrd    r2, r3, [sp, r5]     // vldr does not support non-immediate offsets
        sub     r5, r5, #8
        bl      printf     
        cmp     r5, #0
        BGT     pr_lp
        pop     {r5, lr}
        mov     pc, lr

print_float:                         
        ldr     r0, =float_out       // print out number at sp
        vldr    d1, [sp]
        vmov    r2, r3, d1
        bl      printf
        b       prompt


quit:
        add     sp, sp, r4           // remove all new data from stack
        ldmfd   sp!, {r4, lr}        // restore saved registers
        mov     r0, #0 
        bl      exit

//-----------------------Math Functions         // I end up with a bit of duplicate code, but it is for efficient time wise since I do less comparisons (could probably merge with operand_tests)
math:
        cmp     r4, r1, lsl #3       // check to make sure at least r1 objects (double) in the stack -- r1 is set during operator test
        BLT     error_numOperands
        cmp     r1, #2
        vpopeq  {d1}                 // pop from stack -- stored backwards
        vpop    {d0}
        sub     r1, r1, #1
        sub     r4, r4, r1, lsl #3

        cmp     r0, #'+'             // perform appropriate operation
        vaddeq.f64    d0, d0, d1
        cmp     r0, #'-'
        vsubeq.f64    d0, d0, d1
        cmp     r0, #'*'
        vmuleq.f64    d0, d0, d1
        cmp     r0, #'\/'
        vdiveq.f64    d0, d0, d1
        cmp     r0, #'^'
        bleq    pow
        cmp     r0, #'!'             // x! ~= gamma(x+1)
        bleq    fac
        cmp     r0, #'S'
        bleq    sin
        cmp     r0, #'C'
        bleq    cos
        cmp     r0, #'T'
        bleq    tan
        cmp     r0, #'L'
        bleq    logba

        vpush   {d0}                 // push answer to stack   

        vmrs    r0, FPSCR            // copy FPSCR to check for exceptions https://developer.arm.com/documentation/ddi0344/k/neon-and-vfp-programmers-model/system-registers/floating-point-status-and-control-register--fpscr
                                     //                                          https://docs.oracle.com/cd/E19957-01/806-3568/ncg_handle.html
        tst     r0, #0b11111
        Blne    error_math
   
        b       print_float

fac:
        push       {lr} 
        vcmp.f64   d0, #0         // check if d0 is negative and return nan
        vmrs       APSR_nzcv, FPSCR   // https://books.google.com/books?id=gks1CgAAQBAJ&pg=PA271&lpg=PA271&dq=handle+vfp+exception+handling+arm&source=bl&ots=ORgRyE_04O&sig=ACfU3U1IkcwkP2f0jBbhcBsbWc9DMoiGZw&hl=en&sa=X&ved=2ahUKEwidtIXp3dL0AhXMITQIHaYfBvMQ6AF6BAgdEAM#v=onepage&q&f=false
        vldrlt.f64 d0, =0x7ff8000000000000 // ==NAN
        poplt      {lr}
        movlt      pc, lr

        vpush      {d0}            // check if d0 is non-int and print notice and return gamma approx
        bl         ceil
        vmov.f64   d1, d0
        vpop       {d0}
        vcmp.f64   d0, d1
        vmrs       APSR_nzcv, FPSCR
        vpush      {d0}
        ldrne      r0, =mthex_facd
        ldrne      r1, =stderr
        ldrne      r1, [r1]
        blne       puts
        vpop       {d0}
        
        vldr.f64   d1, =0x3ff0000000000000 // ==1.0
        vadd.f64   d0, d0, d1
        bl      tgamma               // TODO: might need to do a bit of special error handling (maybe give a comment when d0 is not a positive integer) https://en.cppreference.com/w/c/numeric/math/tgamma
        pop     {lr}
        mov     pc, lr

logba:                               // d0 contains a
        push    {lr}                 // d1 contains b
        vpush   {d1}            
        bl      log2                 // d0 == numerator
        vmov.f64    d1, d0
        vpop    {d0}
        vpush   {d1}
        bl      log2                 // d0 == denominator, sp -> numerator
        vpop    {d1}
        vdiv.f64    d0, d1, d0
        pop     {lr}
        mov     pc, lr

//------------------------Error handlers
error_math:                          // Assumes r0 contains FPSCR
        push    {r5, lr}
        mov     r5, r0

        tst     r5, #0b1
        ldrne   r0, =mthex_ioc
        ldrne   r1, =stderr
        ldrne   r1, [r1]
        blne    puts
        tst     r5, #0b10
        ldrne   r0, =mthex_dzc
        ldrne   r1, =stderr
        ldrne   r1, [r1]
        blne    puts
        tst     r5, #0b100
        ldrne   r0, =mthex_ofc
        ldrne   r1, =stderr
        ldrne   r1, [r1]
        blne    puts
        tst     r5, #0b1000
        ldrne   r0, =mthex_ufc
        ldrne   r1, =stderr
        ldrne   r1, [r1]
        blne    puts
        tst     r5, #0b10000
        ldrne   r0, =mthex_ixc
        ldrne   r1, =stderr
        ldrne   r1, [r1]
        blne    puts

        bic     r5, #0b11111
        vmsr    FPSCR, r5            // clear FPSCR
        pop     {r5, lr}
        mov     pc, lr

error_numOperands:
        mov     r2, r0               // Assumes, r0 = cmd, r1 = # ops
        mov     r3, r1
        ldr     r0, =stderr
        ldr     r0, [r0]
        ldr     r1, =err_insufficient_operands
        bl      fprintf
        bl      print_stack
        b       prompt
error_misc:
error_operator:
        mov     r2, r0               // Assumes cmd char is in r0 at call
        ldr     r0, =stderr
        ldr     r0, [r0]
        ldr     r1, =err_bad_cmd
        bl      fprintf
        b       prompt
error_max_in:
        ldr     r0, =stderr
        ldr     r0, [r0]
        ldr     r1, =err_max_input
        ldr     r2, =str_size
        sub     r2, r2, #1
        bl      fprintf
clear_stdin:
        bl      getchar
        cmp     r0, #0
        BLT     error_fgets
        cmp     r0, #'\n'
        BNE     clear_stdin
        b       prompt
error_input:                            
        ldr     r0, =stderr
        ldr     r0, [r0]
        ldr     r1, =err_bad_input
        ldr     r2, =str_in
        bl      fprintf
        b       prompt
error_fgets:
        ldr     r0, =err_no_input
        ldr     r1, =stderr
        ldr     r1, [r1]
        bl      puts
        b       prompt




        .data
welcome_txt:
        .asciz "Welcome, Input (\'h\' for help, \'q\' to quit):"
prompt_txt:
        .asciz "> "
float_in:
        .asciz  "%lG%s"
float_out:
        .asciz  "= %.15G\n"          // printf works with double precision by default
stack_print_str:
        .asciz  "Stack Contains:\n"
looping_out:
        .asciz "\t%.15G\n"
        .align
                                
str_in: .space 64                       
        .equ str_size, (.-str_in)       
        .align                          
dummy_str:
        .space 4
        .align
        
err_no_input:
        .asciz "No valid input detected!"
err_max_input:
        .asciz "Input exceeded maximum character length of %d!\n"
err_bad_input:
        .asciz "Bad input: \"%s\"!\n"
err_bad_cmd:
        .asciz "Unsupported Command: \"%c\"!\n"
err_insufficient_operands:
        .asciz "\"%c\" requires %d operands!\n"
mthex_ioc:
        .asciz "Note: An invalid operation occured."
mthex_dzc:
        .asciz "Note: Division by zero occured."
mthex_ofc:
        .asciz "Note: Overflow occured."
mthex_ufc:
        .asciz "Note: Underflow occured."
mthex_ixc:
        .asciz "Note: Inexact rounding occured."
mthex_facd:
        .asciz "Note: Approximating factorial of non-integer with gamma function."


man:    .ascii "Name\n\tcalc - RPN (postfix) calculator\n\n"
        .ascii "Description\n\tcalc is an RPN calculator. This means that operands are input before the operator and then\n"
        .ascii "\tthe operation takes place, so \"1 2 +\" is equivalent to \"1 + 2\" on an average calulator.\n"
        .ascii "\tOperators and operands can be input one at a time after being prompted, pressing \"Enter\" in between each item.\n\n"
        .ascii "\tOperators are a single case senstive character and require 2 operands unless stated otherwise below.\n"
        .ascii "\tOperands are 64-bit, real, double-precision floats and can be expressed in decimal, hexadecimal, and E-notation.\n"
        .ascii "\t\xC2\xB1INF is also supported, representing \xC2\xB1\xE2\x88\x9E.\n"
        .ascii "\tAll trigonometric functions are performed assuming operands are in radians.\n\n"
        .ascii "Supported Operators:\n\n"
        .ascii "\t+\t\tAddition\n\n"
        .ascii "\t-\t\tSubtraction\n\n"
        .ascii "\t*\t\tMultiplication\n\n"
        .ascii "\t\/\t\tDivision\n\n"
        .ascii "\t^\t\tExponentiation  \tnote: cannot be used for cube root of a negative number\n\n"
        .ascii "\t!\t\tFactorialization\t1 operand\n\n"
        .ascii "\tL\t\tLogarithm       \tsyntax: log\xE2\x82\x93\xE2\x82\x81(x2)\n\n"
        .ascii "\tS\t\tSine            \t1 operand\n\n"
        .ascii "\tC\t\tCosine          \t1 operand\n\n"
        .ascii "\tT\t\tTangent         \t1 operand\n\n"
        .ascii "\nSupported Constants:\n\n"
        .ascii "\tE\t\tEuler's Number  \te \xE2\x89\x88 2.718281828459045\n\n"
        .ascii "\tP\t\tPi              \t\xCF\x80 \xE2\x89\x88 3.141592653589793\n\n"
        .ascii "\nOther Calculator Commands:\n\n"
        .ascii "\th\t\tPrint help information.\n\n"
        .ascii "\tq\t\tQuit out of calc.\n\n"
        .ascii "\tp\t\tPrint stack contents.\n\n"
        .ascii "\tc\t\tClear entire stack.\n\n"
        .asciz "\tz\t\tPop last item from stack."

// https://thinkingeek.com/2013/05/12/arm-assembler-raspberry-pi-chapter-13/
// https://stackoverflow.com/questions/261419/what-registers-to-save-in-the-arm-c-calling-convention
// https://stackoverflow.com/questions/38350891/sigbus-error-assembly-for-arm-processor-on-raspberrypi
// http://vigir.ee.missouri.edu/~gdesouza/ece3210/Lecture_Notes/Lecture16.pdf
