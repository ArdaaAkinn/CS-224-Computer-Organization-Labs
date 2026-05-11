# CS224
# Lab No. 1
# Section 6
# Arda Akın
# 22402316
# Date: Feb 16, 2026

.data
freqTable: .word 0:11
promptSize: .asciiz "Enter the number of elements (positive integer): "
promptElement: .asciiz  "Enter element #"
colonSpace: .asciiz  ": "
space: .asciiz " "
newline: .asciiz "\n"
arrayLabel:  .asciiz "Array contents:\n"
freqLabel: .asciiz "Frequency Table:\n"    

.text
.globl main

main: 
jal createInitArray
add $s0, $v0, $0
add $s1, $v1, $0

la $a0, arrayLabel
li $v0, 4
syscall

add $a0, $s0, $0
add $a1, $s1, $0               
jal PrintArray

la $a2, freqTable          
move $a0, $s0                
move $a1, $s1                
jal FindFreq

la $a0, freqLabel
li $v0, 4
syscall

la $a0, freqTable          
li $a1, 11                 
jal PrintArray

li $v0, 10
syscall
    
createInitArray:
la $a0, promptSize
li $v0, 4
syscall

li $v0, 5
syscall

move $t0, $v0

blez $t0, createInitArray

sll $a0, $t0, 2
li $v0, 9                   
syscall

move $t1, $v0

li $t2, 0

fill_array:
bge $t2, $t0, fill_done

la $a0, promptElement
li $v0, 4
syscall

move $a0, $t2
li $v0, 1
syscall

la $a0, colonSpace
li $v0, 4
syscall

li $v0, 5
syscall

sll $t3, $t2, 2              
add $t4, $t1, $t3           
sw $v0, 0($t4)

addi $t2, $t2, 1
j fill_array

fill_done:
move $v0, $t1
move $v1, $t0
jr $ra

PrintArray:
move $t0, $a0
li $t1, 0

loop_printArray:
beq $t1, $a1, done_printArray

lw $a0, 0($t0)
li $v0, 1
syscall

la $a0, space
li $v0, 4
syscall

addi $t0, $t0, 4
addi $t1, $t1, 1

j loop_printArray

done_printArray:
la $a0, newline
li $v0, 4
syscall

jr $ra

FindFreq:

move $t0, $a2                 
li $t1, 0
                    
zero_loop:
li $t2, 11
bge $t1, $t2, zero_done
sw $zero, 0($t0)

addi $t0, $t0, 4
addi $t1, $t1, 1
j zero_loop

zero_done:
move $t0, $a0                 
li $t1, 0
                    
count_loop:
bge $t1, $a1, count_done

lw $t2, 0($t0)             
bltz $t2, not_digit           
li $t3, 9
bgt $t2, $t3, not_digit      

sll $t4, $t2, 2              
add $t5, $a2, $t4             
lw $t6, 0($t5)
addi $t6, $t6, 1
sw $t6, 0($t5)
j next_element

not_digit:
li $t4, 10
sll $t4, $t4, 2               
add $t5, $a2, $t4             
lw $t6, 0($t5)
addi $t6, $t6, 1
sw $t6, 0($t5)

next_element:
addi $t0, $t0, 4               
addi $t1, $t1, 1
j count_loop

count_done:
jr $ra
