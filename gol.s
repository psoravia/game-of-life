.section ".word"
   /* Game state memory locations */
  .equ CURR_STATE, 0x90001000       /* Current state of the game */
  .equ GSA_ID, 0x90001004           /* ID of the GSA holding the current state */
  .equ PAUSE, 0x90001008            /* Is the game paused or running */
  .equ SPEED, 0x9000100C            /* Current speed of the game */
  .equ CURR_STEP,  0x90001010       /* Current step of the game */
  .equ SEED, 0x90001014             /* Which seed was used to start the game */
  .equ GSA0, 0x90001018             /* Game State Array 0 starting address */
  .equ GSA1, 0x90001058             /* Game State Array 1 starting address */
  .equ CUSTOM_VAR_START, 0x90001200 /* Start of free range of addresses for custom vars */
  .equ CUSTOM_VAR_END, 0x90001300   /* End of free range of addresses for custom vars */
  .equ RANDOM, 0x40000000           /* Random number generator address */
  .equ LEDS, 0x50000000             /* LEDs address */
  .equ SEVEN_SEGS, 0x60000000       /* 7-segment display addresses */
  .equ BUTTONS, 0x70000004          /* Buttons address */

  /* States */
  .equ INIT, 0
  .equ RAND, 1
  .equ RUN, 2

  /* Colors (0bBGR) */
  .equ RED, 0x100
  .equ BLUE, 0x400

  /* Buttons */
  .equ JT, 0x10
  .equ JB, 0x8
  .equ JL, 0x4
  .equ JR, 0x2
  .equ JC, 0x1
  .equ BUTTON_2, 0x80
  .equ BUTTON_1, 0x20
  .equ BUTTON_0, 0x40

  /* LED selection */
  .equ ALL, 0xF

  /* Constants */
  .equ N_SEEDS, 4           /* Number of available seeds */
  .equ N_GSA_LINES, 10       /* Number of GSA lines */
  .equ N_GSA_COLUMNS, 12    /* Number of GSA columns */
  .equ MAX_SPEED, 10        /* Maximum speed */
  .equ MIN_SPEED, 1         /* Minimum speed */
  .equ PAUSED, 0x00         /* Game paused value */
  .equ RUNNING, 0x01        /* Game running value */

.section ".text.init"
  .globl main

main:
  li sp, CUSTOM_VAR_END /* Set stack pointer, grows downwards */ 

outer_start:
  jal reset_game  # jump to reset_game and save position to ra
  jal get_input  # jump to get_input and save position to ra
  mv  s1, a0 # s1 = a0
  li s0, 0 # s0 = 0 -> done = false
inner_start:
  mv a0, s1
  jal select_action  # jump to select_action and save position to ra
  mv a0, s1
  jal update_state  # jump to update_state and save position to ra
  jal update_gsa  # jump to update_gsa and save position to ra
  jal clear_leds  # jump to clear_leds and save position to ra
  jal mask  # jump to mask and save position to ra
  jal draw_gsa  # jump to draw_gsa and save position to ra
  jal wait  # jump to wait and save position to ra
  jal decrement_step  # jump to dece and save position to ra
  mv  s0, a0 # s1 = a0
  jal get_input  # jump to get_input and save position to ra
  mv  s1, a0 # s1 = a0
  beq s0, zero, inner_start; # if s0 == zero then inner_start

  j outer_start  # jump to outer_start

/* BEGIN:clear_leds */
clear_leds:
  la t0, LEDS # load address of LEDS register to register t0
  li t1, 0x7FF # t1 = 0x000007FF : turn off all the LEDs
  sw t1, 0(t0) # write to the memory mapped register representing the LEDs
  ret
/* END:clear_leds */

/* BEGIN:set_pixel */
set_pixel:
  /* Arguments
        register a0 : the pixel's x-coordinate
        register a1 : the pixel's y-coordinate
  */
  la t0, LEDS # load address of LEDS register to register t1
  slli t1, a1, 4 # t1 = a1 << 4
  add t1, t1, a0 # t1 = (a1 << 4) + a0

  # create mask for activating the red part of the LED
  lui t2, 0x10
  addi t2, t2, RED; # t2 = t2 + RED
  
  or t1, t1, t2 # apply the mask
  sw t1, 0(t0) # write to memory the modified memory mapped register representing the LEDs
  ret
/* END:set_pixel */

/* BEGIN:wait */
wait:    
  #li t0, 0x80000 # t0 = 2^19 : initial value of counter for simulating waiting
  li t0, 1024
  la t1, SPEED # pointer to the value of SPEED
  lw t2, 0(t1) # t2 = speed of the game
  
loop_delay:
  sub t0, t0, t2 # t0 = t0 - t2
  bgt t0, zero, loop_delay # if t0 > zero then loop_delay
  
  ret
/* END:wait */

/* BEGIN:set_gsa */
set_gsa:
  /* Arguments
      register a0 : the line
      register a1 : y-coordinate
  */
  slli a1, a1, 2 # a1 = a1 * 4

  la t0, GSA_ID # t0 = address GSA_ID
  lw t0, 0(t0) # t0 = GSA ID (0 or 1)

  beq t0, zero, gsa_is_0_set # if t0 == zero then gsa_is_0_set

  la t0, GSA1 # t0 = address of GSA1
  add t0, t0, a1 # t0 = t0 + a1  : t0 points to line at index y
  sw a0, 0(t0) # GSA1[y] <= a0
  j end_if_set
  
gsa_is_0_set:
  la t0, GSA0 # t0 = address of GSA0
  add t0, t0, a1 # t0 = t0 + a1  : t0 points to line at index y
  sw a0, 0(t0) # GSA0[y] <= a0

end_if_set:
  ret  
/* END:set_gsa */

/* BEGIN:get_gsa */
get_gsa:
  /* Arguments
        register a0 : line y-coordinate
     Return
        register a0 : line at location y in the GSA
  */
  slli a0, a0, 2 # a0 = a0 * 4

  la t0, GSA_ID # t0 = address GSA_ID
  lw t0, 0(t0) # t0 = GSA ID (0 or 1)

  beq t0, zero, gsa_is_0_get # if t0 == zero then gsa_is_0_get

  la t0, GSA1 # t0 = address of GSA1
  add t0, t0, a0 # t0 = t0 + a0  : t0 points to line at index y
  lw a0, 0(t0) # a0 = GSA1[y]
  j end_if_get
  
gsa_is_0_get:
  la t0, GSA0 # t0 = address of GSA0
  add t0, t0, a0 # t0 = t0 + a0  : t0 points to line at index y
  lw a0, 0(t0) # a0 = GSA0[y]

end_if_get:
  ret  
/* END:get_gsa */

/* BEGIN:draw_gsa */
draw_gsa:

  # allocating space on the stack for 4 saved register
  addi sp, sp, -20
  sw s0, 16(sp)
  sw s1, 12(sp)
  sw s2, 8(sp)
  sw s3, 4(sp)
  sw s4, 0(sp)
  

  li s0, N_GSA_LINES # s0 = N_GSA_LINES
  li s1, N_GSA_COLUMNS # s1 = N_GSA_COLUMNS

  li s2, 0 # y-coordinate
  li s3, 0 # x-coordinate
  
  
outer_loop_draw:
  add a0, s2, zero # a0 = s2

  addi sp, sp, -4 # allocating 1 word on the stack
  sw ra, 0(sp) # pushing ra on the stack
  jal get_gsa  # jump to get_gsa and save position to ra
  lw ra, 0(sp) # poping ra off the stack
  addi sp, sp, 4 # de-allocating 3 word off the stack

  add s4, a0, zero # s4 = a0 = gsa[y]

inner_loop_draw:
  andi a0, a0, 1
  bne a0, zero, draw_pixel # if t2 != zero then draw_pixel
  j not_draw_pixel  # jump to not_draw_pixel
  
draw_pixel:
  add a0, s3, zero # a0 = s3
  add a1, s2, zero # a1 = s2

  addi sp, sp, -4 # allocating 1 word on the stack
  sw ra, 0(sp) # pushing ra on the stack
  jal set_pixel  # jump to set_pixel and save position to ra
  lw ra, 0(sp) # poping ra off the stack
  addi sp, sp, 4 # de-allocating 1 word off the stack

not_draw_pixel:
  srli s4, s4, 1
  add a0, s4, zero # a0 = s4
  addi s3, s3, 1 # s3 = s3 + 1
  bne s3, s1, inner_loop_draw # if s3 != s1 then inner_loop_draw
  

  addi s2, s2, 1 # s2 = s2 + 1
  li s3, 0 # reset x-coordinate to 0 for next line
  bne s2, s0, outer_loop_draw # if s2 != s0 then outer_loop_draw

  # de-allocating space on the stack for 4 saved register
  lw s0, 16(sp)
  lw s1, 12(sp)
  lw s2, 8(sp)
  lw s3, 4(sp)
  lw s4, 0(sp)
  addi sp, sp, 20

  ret
/* END:draw_gsa */

/* BEGIN:random_gsa */
random_gsa:

  # allocating space on the stack for 4 saved register
  addi sp, sp, -20
  sw s0, 16(sp)
  sw s1, 12(sp)
  sw s2, 8(sp)
  sw s3, 4(sp)
  sw s4, 0(sp)
  

  li s0, N_GSA_LINES # s0 = N_GSA_LINES
  li s1, N_GSA_COLUMNS # s1 = N_GSA_COLUMNS

  li s2, 0 # y-coordinate
  li s3, 0 # x-coordinate

  la s4, RANDOM # load address of random number generator  

outer_loop_random_gsa:
  li a0, 0 # a0 = 0 : initial state of the GSA element
  
inner_loop_random_gsa:
  lw t0, 0(s4) # t0 = new random number
  andi t0, t0, 1
  slli a0, a0, 1
  add a0, a0, t0 # a0 = a0 + t0
  
  addi s3, s3, 1 # s3 = s3 + 1
  bne s3, s1, inner_loop_random_gsa # if s3 != s1 then inner_loop_random_gsa

  add a1, s2, zero; # a1 = s2
  
  addi sp, sp, -4 # allocating 1 word on the stack
  sw ra, 0(sp) # pushing ra on the stack
  jal set_gsa  # jump to get_gsa and save position to ra
  lw ra, 0(sp) # poping ra off the stack
  addi sp, sp, 4 # de-allocating 3 word off the stack
  
  addi s2, s2, 1 # s2 = s2 + 1
  li s3, 0 # reset x-coordinate to 0 for next line
  bne s2, s0, outer_loop_random_gsa # if s2 != s0 then outer_loop_random_gsa
  
  # de-allocating space on the stack for 4 saved register
  lw s0, 16(sp)
  lw s1, 12(sp)
  lw s2, 8(sp)
  lw s3, 4(sp)
  lw s4, 0(sp)
  addi sp, sp, 20

  ret
/* END:random_gsa */

/* BEGIN:change_speed */
change_speed:
  /* Arguments
        register a0 : 0 if increment, 1 if decrement
  */

  la t0, SPEED # load address of game speed in ram into t0
  lw t1, 0(t0) # t1 = game speed
  li t2, MIN_SPEED # t2 = MIN_SPEED
  li t3, MAX_SPEED # t3 = MAX_SPEED
  
  beq a0, zero, increment_speed; # if a0 == 0 then increment_speed

  ble t1, t2, not_change_speed # if t1 <= t2 then not_change_speed
  addi t1, t1, -1; # t1 = t1 - 1
  j speed_write  # jump to speed_write
  
increment_speed:
  bge t1, t3, not_change_speed; # if t1 >= t3 then not_change_speed
  addi t1, t1, 1; # t1 = t1 + 1

speed_write:
  sw t1, 0(t0) # update game speed in memory

not_change_speed:
  ret
/* END:change_speed */

/* BEGIN:pause_game */
pause_game:
  la t0, PAUSE # load address of pause in ram into t0
  lw t1, 0(t0) # t1 = pause or not
  xori t1, t1, 1 # flip state
  sw t1, 0(t0) # update pause value in ram
  ret
/* END:pause_game */

/* BEGIN:change_steps */
change_steps:
  /* Arguments
        register a0 : 1 if b0 is pressed, 0 otherwise
        register a1 : 1 if b1 is pressed, 0 otherwise
        register a2 : 1 if b2 is pressed, 0 otherwise
  */
  la t0, CURR_STEP # load address of curr_step in ram into t0
  lw t1, 0(t0) # t1 = curr_step

  beq a0, zero, incr_tens; # if a0 == zero then incr_tens
  addi t1, t1, 1 # t1 = t1 + 1
incr_tens:
  beq a1, zero, incr_hundreds; # if a1 == zero then incr_hundreds
  addi t1, t1, 0x10 # t1 = t1 + 16
incr_hundreds:
  beq a2, zero, change_steps_ret; # if a2 == zero then change_steps_ret
  addi t1, t1, 0x100 # t1 = t1 + 256

change_steps_ret:
  li t2, 0xFFF # t2 = 0xFFF
  bgt t1, t2, change_steps_keep_value # if t1 > t2 then change_steps_keep_value
  j change_steps_ret_final  # jump to change_steps_ret_final

change_steps_keep_value:
  li t1, 0xFFF
change_steps_ret_final:
  sw t1, 0(t0) # update value of curr_step in memory
  ret
/* END:change_steps */

/* BEGIN:set_seed */
set_seed:
  /* Arguments:
        register a0: the current seed ID value
  */
  slli a0, a0, 2

  addi sp, sp, -12
  sw s0, 8(sp)
  sw s1, 4(sp)
  sw s2, 0(sp)

  li s0, N_GSA_LINES # s0 = N_GSA_LINES
  li s1, 0 # y-coordinate in the GSA

  la s2, SEEDS # load adress of the the seeds into s2
  add s2, s2, a0 # s2 = address of address of seed number i
  lw s2, 0(s2) # load address of seedi into s2

loop_set_seed:
  lw a0, 0(s2) # a0 = ith line of seed
  add a1, s1, zero # a1 = s1

  addi sp, sp, -4 # sp = sp - 4
  sw ra, 0(sp)
  jal set_gsa
  lw ra, 0(sp)
  addi sp, sp, 4; # sp = sp + 4
  
  addi s1, s1, 1; # s1 = s1 + 1
  addi s2, s2, 4; # s2 = s2 + 4 : s2 points to the next seed line
  bne s1, s0, loop_set_seed # if s1 != s0 then loop_set_seed

  lw s0, 8(sp)
  lw s1, 4(sp)
  lw s2, 0(sp) 
  addi sp, sp, 12  
  
  ret  
/* END:set_seed */

/* BEGIN:increment_seed */
increment_seed:
  la t0, SEED # t0 = address of the SEED ID in use
  la t1, CURR_STATE # t1 = address of the current state of the game

  lw t2, 0(t0) # t2 = current SEED ID
  lw t3, 0(t1) # t3 = current state of the game

  li t4, INIT
  li t5, RAND
  li t6, N_SEEDS

  bge t2, t6, skip_increase_seed_id # if t2 >= t6 then skip_increase_seed_id
  addi t2, t2, 1 # t2 = t2 + 1
  sw t2, 0(t0) # update in memory the value of the SEED ID in use

skip_increase_seed_id:

  beq t3, t5, game_rand # if t3 == t5 then game_rand
  bge t2, t6, game_rand # if t2 >= t6 then game_rand

  beq t3, t4, game_init # if t3 == t4 then game_init
  blt t2, t6, game_init # if t2 < t6 then game_init
  
  j ret_incr_seed  # jump to ret_incr_seed

game_init:
  mv  a0, t2 # a0 = t2

  addi sp, sp, -4 # sp = sp - 4
  sw ra, 0(sp)
  jal set_seed
  lw ra, 0(sp)
  addi sp, sp, 4; # sp = sp + 4

  j ret_incr_seed  # jump to ret_incr_seed
game_rand:
  addi sp, sp, -4 # sp = sp - 4
  sw ra, 0(sp)
  jal random_gsa
  lw ra, 0(sp)
  addi sp, sp, 4; # sp = sp + 4

ret_incr_seed:
  ret
/* END:increment_seed */

/* BEGIN:update_state */
update_state:
  /* Arguments :
        register a0 : BUTTONS
  */

  # allocating space on the stack for 4 saved register
  addi sp, sp, -16
  sw s0, 12(sp)
  sw s1, 8(sp)
  sw s2, 4(sp)
  sw s3, 0(sp)

  la s0, CURR_STEP # s0 = address of current step
  lw t0, 0(s0) # t0 = current step

  bne t0, zero, update_state_game_not_finished # if t0 == zero then update_state_game_not_finished
  
  # put game back to init
  la t0, CURR_STATE # t0 = address of current state
  li t1, INIT # t1 = INIT
  sw t1, 0(t0) # put game to INIT

  j update_state_ret  # jump to update_state_ret
  
update_state_game_not_finished:
  la s0, CURR_STATE # s0 = address of current state
  lw t0, 0(s0) # t0 = current state of the game

  li s1, INIT # s1 = INIT
  li s2, RAND # s2 = RAND
  li s3, RUN # s3 = RUN

  li t1, JC # t1 = JC
  li t2, JR # t2 = JR
  li t3, JB # t3 = JB

  beq t0, s1, update_state_JC_pressed # if t0 == s1 then update_state_JC_pressed
  beq t0, s2, update_state_JR_pressed # if t0 == s2 then update_state_JR_pressed
  beq t0, s3, update_state_JB_pressed # if t0 == s3 then update_state_JB_pressed

  j update_state_ret  # jump to update_state_ret

update_state_JC_pressed:
  andi t0, a0, JC
  bne t0, t1, update_state_JR_pressed # if t0 != t1 then update_state_JR_pressed

  la t4, SEED # t4 = address of the current seed ID in memory
  lw t4, 0(t4) # t4 = current seed ID

  li t5, N_SEEDS # t5 = number of avaiable seeds

  bge t4, t5, update_state_JC_pressed_N_times # if t4 >= t5 then update_state_JC_pressed_N_times

  j update_state_ret  # jump to update_state_ret

update_state_JC_pressed_N_times:
  sw s2, 0(s0) # update current state to RAND
  j update_state_ret  # jump to update_state_ret

update_state_JR_pressed:
  andi t0, a0, JR
  bne t0, t2, update_state_ret # if t0 != t2 then update_state_ret
  sw s3, 0(s0) # update current state to RUN

  li t0, RUNNING
  li t1, PAUSE
  sw t0, 0(t1) # 
  
  
  j update_state_ret  # jump to update_state_ret

update_state_JB_pressed:
  andi t0, a0, JB
  bne t0, t3, update_state_ret # if t0 != t3 then update_state_ret
  sw s1, 0(s0) # update current state to INIT

  # call reset_game
  addi sp, sp, -4 # sp = sp - 4
  sw ra, 0(sp)
  jal reset_game
  lw ra, 0(sp)
  addi sp, sp, 4 # sp = sp + 4

update_state_ret:
  # de-allocating space on the stack for 4 saved register
  lw s0, 12(sp)
  lw s1, 8(sp)
  lw s2, 4(sp)
  lw s3, 0(sp)
  addi sp, sp, 16
  ret
/* END:update_state */

/* BEGIN:select_action */
select_action:
  /* Arguments :
        register a0 : BUTTONS
  */

  # allocating space on the stack for 4 saved register
  addi sp, sp, -32
  sw s0, 28(sp)
  sw s1, 24(sp)
  sw s2, 20(sp)
  sw s3, 16(sp)
  sw s4, 12(sp)
  sw s5, 8(sp)
  sw s6, 4(sp)
  sw s7, 0(sp)

  la s0, CURR_STATE # s0 = address of current state in memory
  lw s0, 0(s0) # s0 = current state

  li s1, INIT # s1 = INIT
  li s2, RAND # s2 = RAND
  li s3, RUN # s3 = RUN

  mv  s4, a0 # s4 = a0 : s4 = BUTTONS

  li t0, BUTTON_0
  and s5, s4, t0
  slt s5, s5, t0
  xori s5, s5, 1

  li t0, BUTTON_1
  and s6, s4, t0
  slt s6, s6, t0
  xori s6, s6, 1

  li t0, BUTTON_2
  and s7, s4, t0
  slt s7, s7, t0
  xori s7, s7, 1
  
  beq s0, s1, select_action_JC_pressed # if s0 == s1 then select_action_JC_pressed
  beq s0, s2, select_action_JC_pressed # if s0 == s2 then select_action_JC_pressed
  beq s0, s3, select_action_JC_pressed_run # if s0 == s3 then select_action_JC_pressed_run

  j select_action_ret  # jump to select_action_ret  

select_action_JC_pressed:
  li t0, JC
  andi t1, a0, JC
  bne t0, t1, select_action_button_0_1_2 # if t0 != t1 then select_action_button_0_1_2
  
  # call increment_seed
  addi sp, sp, -4 # sp = sp - 4
  sw ra, 0(sp)
  jal increment_seed
  lw ra, 0(sp)
  addi sp, sp, 4; # sp = sp + 4

  j select_action_ret  # jump to select_action_ret

select_action_button_0_1_2:
  
  mv  a0, s5 # a0 = s5 
  mv  a1, s6 # a1 = s6
  mv  a2, s7 # a2 = s7
  
  # call change_steps
  addi sp, sp, -4 # sp = sp - 4
  sw ra, 0(sp)
  jal change_steps
  lw ra, 0(sp)
  addi sp, sp, 4; # sp = sp + 4

  j select_action_ret  # jump to select_action_ret


select_action_JC_pressed_run:
  li t0, JC
  andi t1, a0, JC
  bne t0, t1, select_action_JR_pressed_run # if t0 != t1 then select_action_JR_pressed_run

  # call pause_game
  addi sp, sp, -4 # sp = sp - 4
  sw ra, 0(sp)
  jal pause_game
  lw ra, 0(sp)
  addi sp, sp, 4; # sp = sp + 4

  j select_action_ret  # jump to select_action_ret

select_action_JR_pressed_run:
  li t0, JR
  andi t1, a0, JR
  bne t0, t1, select_action_JL_pressed # if t0 != t1 then select_action_JL_pressed

  # call change_speed -> increment speed
  li a0, 0 # a0 = 0
  addi sp, sp, -4 # sp = sp - 4
  sw ra, 0(sp)
  jal change_speed
  lw ra, 0(sp)
  addi sp, sp, 4; # sp = sp + 4

  j select_action_ret  # jump to select_action_ret

select_action_JL_pressed:
  li t0, JL
  andi t1, a0, JL
  bne t0, t1, select_action_JT_pressed # if t0 != t1 then select_action_JT_pressed

  # call change_speed -> decrement speed
  li a0, 1 # a0 = 1
  addi sp, sp, -4 # sp = sp - 4
  sw ra, 0(sp)
  jal change_speed
  lw ra, 0(sp)
  addi sp, sp, 4; # sp = sp + 4

  j select_action_ret  # jump to select_action_ret

select_action_JT_pressed:
  li t0, JT
  andi t1, a0, JT
  bne t0, t1, select_action_ret # if t0 != t1 then select_action_ret

  # call random_gsa
  li a0, 0 # a0 = 0
  addi sp, sp, -4 # sp = sp - 4
  sw ra, 0(sp)
  jal random_gsa
  lw ra, 0(sp)
  addi sp, sp, 4; # sp = sp + 4
  

select_action_ret:
  lw s0, 28(sp)
  lw s1, 24(sp)
  lw s2, 20(sp)
  lw s3, 16(sp)
  lw s4, 12(sp)
  lw s5, 8(sp)
  lw s6, 4(sp)
  lw s7, 0(sp)
  addi sp, sp, 32
  ret
/* END:select_action */

/* BEGIN:cell_fate */
cell_fate:
  /* Arguments :
        register a0 : number of living neighbouring cells
        register a1 : exeamineated cell state
     Return Value :
        register a0 : 1 if the cell is alive 0 otherwise
  */

  li t0, 2 # min number of neighbours
  li t1, 3 # max number of neighbours and number of neighbours to give birth to a cell

  beq a1, zero, is_dead; # if a1 == zero then is_dead
  
  blt a0, t0, cell_death # if a0 < t0 then cell_death
  bgt a0, t1, cell_death # if a0 > t1 then cell_death
  j cell_birth  # jump to cell_birth
  
is_dead:
  beq a0, t1, cell_birth; # if a0 == t1 then cell_birth
cell_death:
  li a0, 0 # a0 = 0
  j ret_cell_fate  # jump to ret_cell_fate
cell_birth:
  li a0, 1 # a0 = 1
ret_cell_fate:
  ret
/* END:cell_fate */

/* BEGIN:find_neighbours */
find_neighbours:
  /* Arguments :
        register a0 : x coordinate of examinated cell
        register a1 : y coordinate of examinated cell
     Return Value :
        registre a0 : number of living neighbours
        register a1 : state of the cell at location (x, y) (the cell we are counting the living neighbors)
  */
  addi sp, sp, -4 # sp = sp - 4
  sw s0, 0(sp)
  li s0, 0 # s0 = 0 : counter for number of living cells

  la t0, GSA_ID # t0 = address GSA_ID
  lw t0, 0(t0) # t0 = GSA ID (0 or 1)

  beq t0, zero, gsa_is_0_find_neighbours; # if t0 == zero then gsa_is_0_find_neighbours
  
  la t0, GSA1

  j find_neighbours_in_curr_gsa  # jump to find_neighbours_in_curr_gsa
  
gsa_is_0_find_neighbours:
  la t0, GSA0

find_neighbours_in_curr_gsa:
  slli t1, a1, 2
  add t1, t0, t1 # t1 = t0 + t1  : t1 points to line at index y
  lw t1, 0(t1) # t1 = curr_gsa[y]
  srl t1, t1, a0
  andi t1, t1, 1 # t1 = curr_gsa[y][x]

  li t2, -1 # t2 = -1 # y coordinate iterator
  li t3, -1 # t3 = -1 # x coordinate iterator
  
iterate_neighbours_outer:
  add t4, t2, a1 # t4 = t2 + a1

  li t6, N_GSA_LINES
  blt t4, zero, find_neighbours_negative_y_corr # if t4 < zero then find_neighbours_negative_y_corr
  bge t4, t6, find_neighbours_too_big_y_corr # if t4 >= t6 then find_neighbours_too_big_y_corr
  j find_neighbours_y_corr_in_bounds  # jump to find_neighbours_y_corr_in_bounds
  
find_neighbours_negative_y_corr:
  add t4, t6, t4 # t4 = t6 + t4   : do modulo -y mod 10
  j find_neighbours_y_corr_in_bounds  # jump to find_neighbours_y_corr_in_bounds

find_neighbours_too_big_y_corr:
  sub t4, t4, t6 # t4 = t4 - t6 : do modulo Y mod 10

find_neighbours_y_corr_in_bounds:
  slli t4, t4, 2
  add t4, t0, t4 # t4 = t0 + t4  
  lw t4, 0(t4) # t4 = curr_gsa[y +- y-shift]

iterate_neighbours_inner:
  beq t3, zero, find_neighbours_x_shift_zero # if t3 == zero then find_neighbours_x-shift_zero
  j find_neighbours_x_shift_y_shift_not_both_zero  # jump to find_neighbours_x_shift_y_shift_not_both_zero

find_neighbours_x_shift_zero:
  beq t2, zero, iterate_skip_inner # if t2 == zero then iterate_skip_inner

find_neighbours_x_shift_y_shift_not_both_zero:
  add t5, t3, a0 # t5 = t3 + a0

  li t6, N_GSA_COLUMNS
  blt t5, zero, find_neighbours_negative_x_corr # if t5 < zero then find_neighbours_negative_x_corr
  bge t5, t6, find_neighbours_too_big_x_corr # if t5 >= t6 then find_neighbours_too_big_x_corr
  j find_neighbours_x_corr_in_bounds  # jump to find_neighbours_x_corr_in_bounds
  
find_neighbours_negative_x_corr:
  add t5, t6, t5 # t5 = t6 + t5 : do modulo -x mod 12
  j find_neighbours_x_corr_in_bounds  # jump to find_neighbours_x_corr_in_bounds
  
find_neighbours_too_big_x_corr:
  sub t5, t5, t6 # t5 = t5 - t6 : do modulo X modulo 12
  
find_neighbours_x_corr_in_bounds:
  srl t5, t4, t5
  andi t5, t5, 1 # t5 = curr_gsa[y +- y-shift][x +- x-shift]
  add s0, s0, t5 # s0 = s0 + t5  

iterate_skip_inner:
  addi t3, t3, 1 # t3 = t3 + 1
  li t6, 2 # t6 = 2
  blt t3, t6, iterate_neighbours_inner # if t3 < 2 then iterate_neighbours_inner

  li t3, -1 # t3 = -1
  addi t2, t2, 1; # t2 = t2 + 1
  li t6, 2  # t6 = 2
  blt t2, t6, iterate_neighbours_outer # if t2 < t6 then iterate_neighbours_outer
  
  mv  a0, s0 # a0 = s0
  mv  a1, t1 # a1 = t1

  # de-allocate memory
  lw s0, 0(sp)
  addi sp, sp, 4; # sp = sp + 4

  ret
/* END:find_neighbours */

/* BEGIN:update_gsa */
update_gsa:
  la t0, PAUSE # t0 = address game pause value
  lw t0, 0(t0) # t0 = 0 (game is paused) or 1

  beq t0, zero, update_gsa_ret # if t0 == zero then update_gsa_ret

  la t0, CURR_STATE # t0 = address of current state
  lw t0, 0(t0) # t0 = current state of the game

  li t1, RUN # t1 = RUN
  
  bne t0, t1, update_gsa_ret # if t0 != t1 then update_gsa_ret

  # allocating space on the stack for 9 saved register
  addi sp, sp, -28
  sw s0, 24(sp)
  sw s1, 20(sp)
  sw s2, 16(sp)
  sw s3, 12(sp)
  sw s4, 8(sp)
  sw s5, 4(sp)
  sw s6, 0(sp)
  

  li s0, N_GSA_LINES # s0 = N_GSA_LINES
  li s1, N_GSA_COLUMNS # s1 = N_GSA_COLUMNS

  li s2, 0 # y-coordinate
  li s3, 0 # x-coordinate

  la s4, GSA_ID
  lw t0, 0(s4) # t0 = GSA_ID
  beq t0, zero, update_gsa_0 # if s4 == zero then update_gsa_0

  la s5, GSA0 # adress of next_gsa

  j update_gsa_outer_loop  # jump to update_gsa_outer_loop
  
update_gsa_0:
  la s5, GSA1
  
update_gsa_outer_loop:
  li s6, 0 # s6 = next_gsa

update_gsa_inner_loop:
  mv a0, s3 # a0 = s3
  mv  a1, s2 # a1 = s2

  # call find_neighbours
  addi sp, sp, -4 # allocating 1 word on the stack
  sw ra, 0(sp) # pushing ra on the stack
  jal find_neighbours  # jump to find_neighbours and save position to ra
  lw ra, 0(sp) # poping ra off the stack
  addi sp, sp, 4 # de-allocating 1 word off the stack

  # call cell_fate
  addi sp, sp, -4 # allocating 1 word on the stack
  sw ra, 0(sp) # pushing ra on the stack
  jal cell_fate  # jump to cell_fate and save position to ra
  lw ra, 0(sp) # poping ra off the stack
  addi sp, sp, 4 # de-allocating 1 word off the stack

  sll a0, a0, s3
  or s6, s6, a0

  addi s3, s3, 1; # s3 = s3 + 1
  blt s3, s1, update_gsa_inner_loop # if s3 < s1 then update_gsa_inner_loop
  
  slli t0, s2, 2
  add t0, t0, s5 # t0 = t0 + s5
  sw s6, 0(t0) # update line of next_gsa

  li s3, 0 # s3 = 0
  addi s2, s2, 1; # s2 = s2 + 1
  blt s2, s0, update_gsa_outer_loop # if s2 < s0 then update_gsa_outer_loop
  
  lw t0, 0(s4) # t0 = GSA_ID
  xori t0, t0, 1 # invert GSA_ID
  sw t0, 0(s4) # update GSA_ID in memory
  
  # de-allocating space on the stack for 9 saved register
  lw s0, 24(sp)
  lw s1, 20(sp)
  lw s2, 16(sp)
  lw s3, 12(sp)
  lw s4, 8(sp)
  lw s5, 4(sp)
  lw s6, 0(sp)
  addi sp, sp, 28

update_gsa_ret:
  ret
/* END:update_gsa */

/* BEGIN:get_input */
get_input:
  /*
    Returns :
        register a0: BUTTONS register
  */

  la t0, BUTTONS # t0 = address of the buttons memory mapped register
  lw t1, 0(t0) # t1 = BUTTONS

  li t2, JC # first button to check
  li t3, JT # last button to check

get_input_processing_loop:
  and t4, t1, t2
  beq t4, t2, get_input_ret # if t4 == t2 then get_input_ret
  
  slli t2, t2, 1

  bge t3, t2, get_input_processing_loop # if t3 >= t2 then get_input_processing_loop

  andi t4, t1, 0xE0

  # mv  t4, zero # t4 = zero

get_input_ret:
  mv  a0, t4 # a0 = t4
  sw zero, 0(t0) # clear BUTTONS memory mapped register
  ret
/* END:get_input */

/* BEGIN:decrement_step */
decrement_step:
  addi sp, sp, -8
  sw s0, 4(sp)
  sw s1, 0(sp)
  
  la s0, CURR_STEP # s0 = address of current step
  lw s1, 0(s0) # s1 = current step

  beq s1, zero, decrement_step_curr_step_zero; # if s1 == zero then decrement_step_curr_step_zero
  

  la t0, CURR_STATE # t0 = address of current state
  lw t0, 0(t0) # t0 = current state

  xori t1, t0, INIT
  beq t1, zero, decrement_step_show_steps # if t1 == zero then decrement_step_show_steps
  
  xori t1, t0, RAND
  beq t1, zero, decrement_step_show_steps # if t1 == zero then decrement_step_show_steps
  
  la t0, PAUSE # t0 = adress of pause
  lw t0, 0(t0) # t0 = pause or not
  xori t0, t0, RUNNING
  bne t0, zero, decrement_step_ret # if t0 != zero then decrement_step_ret


  addi s1, s1, -1 # s1 = s1 + -1

  sw s1, 0(s0) # update current step

  
decrement_step_show_steps: 
  la t1, font_data # t1 = address of font_data
  li t3, 0 # t3 = led array
  li t4, 0 # loop index
  li t6, 4 # bound of loop

decrement_step_loop:
  andi t2, s1, ALL # take last digit
  slli t2, t2, 2 # multipli by 4
  add t2, t1, t2 # t2 = t1 + t2
  lw t2, 0(t2) # t2 = corresponding digit for units

  slli t5, t4, 3
  sll t2, t2, t5
  or t3, t3, t2

  srli s1, s1, 4
  addi t4, t4, 1

  blt t4, t6, decrement_step_loop # if t4 < t6 then decrement_step_loop

  la t6, SEVEN_SEGS # t6 = address of seven segs

  sw t3, 0(t6) # update 7-SEGS display

  li a0, 0 # a0 = 0
  j decrement_step_ret  # jump to decrement_step_ret
  
decrement_step_curr_step_zero:
  li a0, 1 # a0 = 1
decrement_step_ret:
  lw s0, 4(sp)
  lw s1, 0(sp)
  addi sp, sp, 8
  ret
/* END:decrement_step */

/* BEGIN:reset_game */
reset_game:
  # CURR_STEP is 1
  la t0, CURR_STEP # t0 = address of current step
  li t1, 1 # t1 = 1
  sw t1, 0(t0) # set current step to 1

  # CURR_STEP (which is 1) is displayed on the 7-SEGS display
  li t4, 0 # t4 = 0 what to write to 7-SEGS display
  la t0, SEVEN_SEGS # t0 = address of 7-SEGS display
  la t2, font_data # t2 = address of font_data
  addi t3, t2, 4 # t3 = t2 + 4
  lw t3, 0(t3) # t3 = corresponding digit for units to display 1
  or t4, t4, t3
  lw t3, 0(t2) # t3 = corresponding digit for units to display 0
  slli t3, t3, 8
  or t4, t4, t3
  slli t3, t3, 8 
  or t4, t4, t3
  slli t3, t3, 8 
  or t4, t4, t3
  sw t4, 0(t0) # display 001 on 7-SEGS display

  # SEED0 is selected
  la t0, SEED # address of seed
  li t1, 0 # t1 = 0
  sw t1, 0(t0) # seed ID is set to 0

  # GSA0 is initialized to seed0
  la t0, GSA_ID # t0 = address of gsa ID
  li t1, 0 # t1 = 0
  sw t1, 0(t0) # gsa ID is set to 0

  # call set_seed
  li a0, 0 # a0 = 0
  addi sp, sp, -4 # allocating 1 word on the stack
  sw ra, 0(sp) # pushing ra on the stack
  jal set_seed  # jump to set_seed and save position to ra
  lw ra, 0(sp) # poping ra off the stack
  addi sp, sp, 4 # de-allocating 1 word off the stack

  # call draw_gsa
  addi sp, sp, -4 # allocating 1 word on the stack
  sw ra, 0(sp) # pushing ra on the stack
  jal clear_leds  # jump to clear_leds and save position to ra
  lw ra, 0(sp) # poping ra off the stack
  addi sp, sp, 4 # de-allocating 1 word off the stack

  addi sp, sp, -4 # allocating 1 word on the stack
  sw ra, 0(sp) # pushing ra on the stack
  jal mask  # jump to mask and save position to ra
  lw ra, 0(sp) # poping ra off the stack
  addi sp, sp, 4 # de-allocating 1 word off the stack

  addi sp, sp, -4 # allocating 1 word on the stack
  sw ra, 0(sp) # pushing ra on the stack
  jal draw_gsa  # jump to draw_gsa and save position to ra
  lw ra, 0(sp) # poping ra off the stack
  addi sp, sp, 4 # de-allocating 1 word off the stack

  # game is paused
  la t0, PAUSE # t0 = address of pause
  li t1, PAUSED # t1 = PAUSED
  sw t1, 0(t0) # game is set to PAUSED
  
  # game speed is 1
  la t0, SPEED # t0 = address of SPEED
  li t1, MIN_SPEED # t1 = MIN_SPEED
  sw t1, 0(t0) # gmae speed = MIN_SPEED

  # game state is INIT
  la t0, CURR_STATE # address of current game state
  li t1, INIT # t1 = INIT
  sw t1, 0(t0) # ste current game state to INIT 
  
  ret
/* END:reset_game */

/* BEGIN:mask */
mask:
  addi sp, sp, -16
  sw s0, 12(sp)
  sw s1, 8(sp)
  sw s2, 4(sp)
  sw s3, 0(sp)

  li s0, N_GSA_LINES # s0 = N_GSA_LINES
  li s1, 0 # y-coordinate in the GSA

  la t0, SEED # t0 = adress of seed ID
  lw t0, 0(t0) # t0 = seed ID
  slli t0, t0, 2

  la s2, MASKS # s2 = adress of masks
  add s2, s2, t0 # s2 = address address of mask number i

  lw s2, 0(s2) # s2 = address of maski

mask_loop:
  lw s3, 0(s2) # s3 = ith line of mask
  
  mv a0, s1
  addi sp, sp, -4
  sw ra, 0(sp)
  jal get_gsa
  lw ra, 0(sp)
  addi sp, sp, 4

  and a0, s3, a0

  mv a1, s1 # a1 = s1
  addi sp, sp, -4 # sp = sp - 4
  sw ra, 0(sp)
  jal set_gsa
  lw ra, 0(sp)
  addi sp, sp, 4 # sp = sp + 4

  xori s3, s3, -1
  slli s3, s3, 16
  ori s3, s3, BLUE
  slli t0, s1, 4
  or s3, s3, t0
  ori s3, s3, ALL
  la t0, LEDS # t0 = address of LEDS register
  sw s3, 0(t0) # draw the line of the mask

  addi s1, s1, 1; # s1 = s1 + 1
  addi s2, s2, 4; # s2 = s2 + 4 : s2 points to the next seed line
  bne s1, s0, mask_loop # if s1 != s0 then mask_loop


  lw s0, 12(sp)
  lw s1, 8(sp)
  lw s2, 4(sp)
  lw s3, 0(sp)
  addi sp, sp, 16
  
  ret
  
/* END:mask */

/* 7-segment display */
font_data:
  .word 0x3F
  .word 0x06
  .word 0x5B
  .word 0x4F
  .word 0x66
  .word 0x6D
  .word 0x7D
  .word 0x07
  .word 0x7F
  .word 0x6F
  .word 0x77
  .word 0x7C
  .word 0x39
  .word 0x5E
  .word 0x79
  .word 0x71

  seed0:
	.word 0xC00
	.word 0xC00
	.word 0x000
	.word 0x060
	.word 0x0A0
	.word 0x0C6
	.word 0x006
	.word 0x000
  .word 0x000
  .word 0x000

seed1:
	.word 0x000
	.word 0x000
	.word 0x05C
	.word 0x040
	.word 0x240
	.word 0x200
	.word 0x20E
	.word 0x000
  .word 0x000
  .word 0x000

seed2:
	.word 0x000
	.word 0x010
	.word 0x020
	.word 0x038
	.word 0x000
	.word 0x000
	.word 0x000
	.word 0x000
  .word 0x000
  .word 0x000

seed3:
	.word 0x000
	.word 0x000
	.word 0x090
	.word 0x008
	.word 0x088
	.word 0x078
	.word 0x000
	.word 0x000
  .word 0x000
  .word 0x000


# Predefined seeds
SEEDS:
  .word seed0
  .word seed1
  .word seed2
  .word seed3

mask0:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
  .word 0xFFF
  .word 0xFFF

mask1:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x1FF
	.word 0x1FF
	.word 0x1FF
  .word 0x1FF
  .word 0x1FF

mask2:
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
  .word 0x7FF
  .word 0x7FF

mask3:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x000
  .word 0x000
  .word 0x000

mask4:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x000
  .word 0x000
  .word 0x000

MASKS:
  .word mask0
  .word mask1
  .word mask2
  .word mask3
  .word mask4
