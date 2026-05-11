.data

message: .asciiz "Enter a decimal number: "
original: .asciiz "\nOriginal: "
final: .asciiz "\nFinal: "

.text
.globl main

main:
li $v0, 4
la $a0, message
syscall

li $v0, 5 
syscall
add $t0, $v0, $0

li $v0, 4
la $a0, original
syscall

li $v0, 34 #hex print
la $a0, 0($t0)
syscall

add $a0, $t0, 0
jal swap

add $t0, $v0, $0 

li $v0, 4
la $a0, final
syscall

li $v0, 34
la $a0, 0($t0) 
syscall

li $v0, 10
syscall

swap:
add $t0, $a0, $0

li $t1, 0xFF000000
and $t2, $t1, $t0

li $t1, 0x00FF0000
and $t3, $t1, $t0

li $t1, 0x0000FF00
and $t4, $t1, $t0

li $t1, 0x000000FF
and $t5, $t1, $t0

srl $t3,$t3,8
sll $t4,$t4,8

or $v0, $t2, $t3
or $v0, $v0, $t4
or $v0, $v0, $t5

jr $ra
