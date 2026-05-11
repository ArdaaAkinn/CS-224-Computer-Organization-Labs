.data
array:     .word 2, 4, 8, 2, 8, 1, 4, 1, 1, 4
arrSize:   .word 10 

.text
.globl main
main:

la $a0, array
lw $a1, arrSize

jal PrintArray

la $a0, array
lw $a1, arrSize
jal FindSum

move $a0, $v0
li $v0, 1
syscall

li $a0, 10
li $v0, 11
syscall

la $a0, array
lw $a1, arrSize 
jal FindMinMax

move $a0, $v0
li $v0, 1
syscall

li $a0, 32
li $v0, 11
syscall

move $a0, $v1
li $v0, 1
syscall

li $a0, 10
li $v0, 11
syscall

la $a0, array
lw $a1, arrSize
li $a2, 2
jal CountAnEntry

move $a0, $v0
li $v0, 1
syscall

li $v0, 10
syscall

PrintArray:
li $t0, 0
move $t1, $a0

loop_PrintArray:
beq $t0, $a1, done_PrintArray
sll $t2, $t0, 2
add $t3, $t1, $t2
lw $t4, 0($t3)

move $a0, $t4
li $v0, 1
syscall

li $a0, 32 #space
li $v0, 11
syscall

addi $t0, $t0, 1
j loop_PrintArray

done_PrintArray:
li $a0, 10 #newline
li $v0, 11
syscall

move $a0, $t1
jr $ra

FindSum:
li $t0, 0
li $t1, 0
add $t2, $a0, $0

loop_FindSum:
beq $t0, $a1, done_FindSum

sll $t3, $t0, 2
add $t4, $t2, $t3
lw $t5, 0($t4)

add $t1, $t1, $t5

addi $t0, $t0, 1
j loop_FindSum

done_FindSum:
move $v0, $t1
move $a0, $t2
jr $ra

FindMinMax:
li $t2, 0 
move $t0, $a0

lw $t1, 0($t0)
move $t6, $t1
move $t7, $t1

loop_FindMinMax:

beq $t2, $a1, done_FindMinMax
sll $t3, $t2, 2
add $t4, $t0, $t3
lw $t5, 0($t4)

blt $t5, $t6, newMin
bgt  $t5, $t7, newMax
j next_FindMinMax 

next_FindMinMax:
addi $t2, $t2, 1
j loop_FindMinMax

newMin:
move $t6, $t5
j next_FindMinMax

newMax:
move $t7, $t5
j next_FindMinMax

done_FindMinMax:
add $a0, $t0, $0
add $v0, $t6, $0
add $v1, $t7, $0
jr $ra

CountAnEntry:
add $t0, $a0, $0        
add $t1, $a1, $0        
add $t2, $a2, $0   #count number     

sll $t3, $t2, 2
add $t3, $t3, $t0
lw  $t4, 0($t3)

li $t5, 0            # count
li $t6, 0            # index

loop_CountAnEntry:
beq $t6, $t1, done_CountAnEntry

sll $t7, $t6, 2
add $t7, $t7, $t0
lw  $t8, 0($t7)

beq $t8, $t4, inc_Count
j next_Count

inc_Count:
addi $t5, $t5, 1

next_Count:
addi $t6, $t6, 1
j loop_CountAnEntry

done_CountAnEntry:
move $v0, $t5
move $a0, $t0
jr $ra