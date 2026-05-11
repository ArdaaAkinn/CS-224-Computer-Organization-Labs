.data 
size: .asciiz "Enter size: "
value: .asciiz "Enter value: "
original: .asciiz "Original: "
final: .asciiz "\nFinal: "
space: .asciiz " "

.text
.globl main
main:

li $v0, 4
la $a0, size
syscall 

li $v0, 5
syscall

add $s0, $v0, 0

sll $a0,$s0,2       # allocating array
li $v0,9
syscall
add $s1,$v0,$0      # array address

add $t0, $0, $0 

fillLoop:
slt $at, $t0, $s0
beq $at, $0, done

li $v0, 4
la $a0, value
syscall

li $v0, 5
syscall

sll $t1, $t0, 2 # i*4
add $t1, $s1, $t1
sw $v0, 0($t1)

addi $t0, $t0, 1
j fillLoop

done:
li $v0, 4
la $a0, original
syscall

add $a0, $s1, $0
add $a1, $s0, $0
jal printArray

add $a0, $s1, $0
add $a1, $s0, $0
jal reverseArray

li $v0, 4
la $a0, final
syscall

add $a0, $s1, $0
add $a1, $s0, $0
jal printArray

li $v0,10
syscall

printArray:
add $t0, $0, $0
add $t6, $a0, $0

printLoop:
slt $at, $t0, $a1
beq $at, $0, printDone

sll $t1, $t0, 2
add $t1, $t6, $t1

lw $a0, 0($t1)
li $v0, 1
syscall

li $v0, 4
la $a0, space
syscall

addi $t0, $t0, 1
j printLoop

printDone:
jr $ra

reverseArray:

add $t0, $0, $0
addi $t1, $a1, -1

reverseLoop:
slt $at, $t0, $t1
beq $at, $0, reverseDone

sll $t2, $t0, 2
add $t2, $a0, $t2

sll $t3, $t1, 2
add $t3, $a0, $t3

lw $t4, 0($t2)
lw $t5, 0($t3)

sw $t5, 0($t2)
sw $t4, 0($t3)

addi $t0, $t0, 1
addi $t1, $t1, -1
j reverseLoop

reverseDone:
jr $ra
