[ORG 0x0000]
[BITS 16]

kernel_main:
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov ax, 0xB800
    mov gs, ax

    ; 1. 设置文本模式并清屏
    mov ax, 0x0003
    int 0x10

    ; 2. 隐藏 VGA 硬件光标（消除左上角闪烁小横杠）
    mov ah, 0x01
    mov cx, 0x2607          ; 隐藏光标的标准 BIOS 设置
    int 0x10

    ; ====================================================
    ; 阶段 1：展示开机动态 ZZX OS LOGO (10秒)
    ; ====================================================
    call draw_boot_logo_animated
    
    mov cx, 6              
.logo_delay:
    call sleep_1s
    loop .logo_delay

    ; ====================================================
    ; 阶段 2：POST 开机自检 (15项，每项1秒，共15秒)
    ; ====================================================
    mov ax, 0x0003          
    int 0x10
    
    mov cx, 15              
    mov bx, post_messages   
.post_loop:
    mov si, [bx]
    call print_bios_str
    call sleep_1s
    add bx, 2
    loop .post_loop

    call sleep_1s           

    ; ====================================================
    ; 阶段 3：直接进入主界面 (已删除登录环节)
    ; ====================================================
    call draw_split_screen

shell_loop:
    mov ah, 0x00
    int 0x16

    cmp ah, 0x30            ; Alt+B 切换焦点
    jne .process_input
    push ax
    mov ah, 0x02
    int 0x16
    test al, 0x08
    pop ax
    jz .process_input
    
    xor byte [active_focus], 1
    call update_focus_status
    jmp shell_loop

.process_input:
    cmp byte [active_focus], 1
    je handle_file_manager

; ====================================================
; 左侧 SHELL 核心处理
; ====================================================
handle_shell_input:
    cmp al, 0x0D
    je .exec_cmd
    cmp al, 0x08
    je .handle_backspace
    cmp al, 0x20
    jb shell_loop

    mov bl, [cmd_len]
    cmp bl, 16
    jge shell_loop

    mov bh, 0
    mov [cmd_buffer + bx], al
    inc byte [cmd_len]
    mov bl, [cmd_len]
    mov byte [cmd_buffer + bx], 0

    call redraw_shell_input
    jmp shell_loop

.handle_backspace:
    cmp byte [cmd_len], 0
    jle shell_loop
    dec byte [cmd_len]
    mov bh, 0
    mov bl, [cmd_len]
    mov byte [cmd_buffer + bx], 0
    call redraw_shell_input
    jmp shell_loop

.exec_cmd:
    call freeze_current_line
    cmp byte [cmd_len], 0
    je .next_prompt

    mov si, cmd_buffer
    
    mov di, cmd_guide
    call streq
    jc .do_guide
    
    mov di, cmd_wipe
    call streq
    jc .do_wipe
    
    mov di, cmd_render
    call streq
    jc .do_render
    
    mov di, cmd_info
    call streq
    jc .do_info
    
    mov di, cmd_sysver
    call streq
    jc .do_sysver
    
    mov di, cmd_memory
    call streq
    jc .do_memory
    
    mov di, cmd_storage
    call streq
    jc .do_storage
    
    mov di, cmd_network
    call streq
    jc .do_network
    
    mov di, cmd_process
    call streq
    jc .do_process
    
    mov di, cmd_hardware
    call streq
    jc .do_hardware
    
    mov di, cmd_datetime
    call streq
    jc .do_datetime
    
    mov di, cmd_diag
    call streq
    jc .do_diag
    
    mov di, cmd_beep
    call streq
    jc .do_beep
    
    mov di, cmd_lock
    call streq
    jc .do_lock
    
    mov di, cmd_poweroff
    call streq
    jc .do_poweroff

    mov si, res_unknown
    jmp .print_res

; --- 修正后的指令返回块 ---
.do_guide:
    mov si, res_guide
    jmp .print_res
.do_info:
    mov si, res_info
    jmp .print_res
.do_sysver:
    mov si, res_sysver
    jmp .print_res
.do_memory:
    mov si, res_memory
    jmp .print_res
.do_storage:
    mov si, res_storage
    jmp .print_res
.do_network:
    mov si, res_network
    jmp .print_res
.do_process:
    mov si, res_process
    jmp .print_res
.do_hardware:
    mov si, res_hardware
    jmp .print_res
.do_datetime:
    mov si, res_datetime
    jmp .print_res
.do_diag:
    mov si, res_diag
    jmp .print_res
; --------------------------

.do_wipe:
    mov byte [shell_row], 2
    call clear_left_shell
    jmp .force_reset

.do_render:
    call do_3d_demo
    call flush_keyboard_buffer
    call draw_split_screen
    jmp .force_reset

.do_beep:
    mov si, res_beep
    call print_shell_response
    mov ax, 0x0E07          
    int 0x10
    jmp .next_prompt

.do_lock:
    jmp kernel_main         

.do_poweroff:
    mov ax, 0x0003
    int 0x10
    mov si, msg_halt
    call print_bios_str
    cli
    hlt                     

.print_res:
    call print_shell_response

.next_prompt:
    inc byte [shell_row]
    cmp byte [shell_row], 22
    jl .force_reset
    mov byte [shell_row], 2
    call clear_left_shell

.force_reset:
    mov cx, 24
    mov bx, 0
.clear_buf_loop:
    mov byte [cmd_buffer + bx], 0
    inc bx
    loop .clear_buf_loop
    mov byte [cmd_len], 0

    call draw_shell_prompt
    call redraw_shell_input
    jmp shell_loop

; ====================================================
; 延时与动画控制
; ====================================================
sleep_1s:
    pusha
    mov ah, 0x86
    mov cx, 0x000F          
    mov dx, 0x4240
    int 0x15
    popa
    ret

sleep_200ms:
    pusha
    mov ah, 0x86
    mov cx, 0x0003          
    mov dx, 0x0D40
    int 0x15
    popa
    ret

print_bios_str:
    pusha
    mov ah, 0x0E
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    popa
    ret

; ====================================================
; ZZX OS 开启动画引擎 (修正为正向 ZZX OS)
; ====================================================
draw_boot_logo_animated:
    xor di, di
    mov cx, 80*25
.bg_loop:
    mov word [gs:di], 0x0020
    add di, 2
    loop .bg_loop

    mov byte [logo_color], 0x0B
    
    mov si, logo_line1
    mov di, (8 * 160) + (17 * 2)
    call write_tui_str_color_var
    call sleep_200ms

    mov si, logo_line2
    mov di, (9 * 160) + (17 * 2)
    call write_tui_str_color_var
    call sleep_200ms

    mov si, logo_line3
    mov di, (10 * 160) + (17 * 2)
    call write_tui_str_color_var
    call sleep_200ms

    mov si, logo_line4
    mov di, (11 * 160) + (17 * 2)
    call write_tui_str_color_var
    call sleep_200ms

    mov si, logo_line5
    mov di, (12 * 160) + (17 * 2)
    call write_tui_str_color_var
    call sleep_200ms

    mov cx, 5
.pulse_loop:
    mov byte [logo_color], 0x09     
    call redraw_logo_fast
    call sleep_200ms
    mov byte [logo_color], 0x0A     
    call redraw_logo_fast
    call sleep_200ms
    mov byte [logo_color], 0x0B     
    call redraw_logo_fast
    call sleep_200ms
    loop .pulse_loop

    mov byte [logo_color], 0x0C     
    mov si, logo_text
    mov di, (15 * 160) + (26 * 2)
    call write_tui_str_color_var
    ret

redraw_logo_fast:
    mov si, logo_line1
    mov di, (8 * 160) + (17 * 2)
    call write_tui_str_color_var
    mov si, logo_line2
    mov di, (9 * 160) + (17 * 2)
    call write_tui_str_color_var
    mov si, logo_line3
    mov di, (10 * 160) + (17 * 2)
    call write_tui_str_color_var
    mov si, logo_line4
    mov di, (11 * 160) + (17 * 2)
    call write_tui_str_color_var
    mov si, logo_line5
    mov di, (12 * 160) + (17 * 2)
    call write_tui_str_color_var
    ret

write_tui_str_color_var:
    mov ah, [logo_color]
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [gs:di], ax
    add di, 2
    jmp .loop
.done:
    ret

; ====================================================
; TUI 界面核心与工具函数
; ====================================================
flush_keyboard_buffer:
.loop:
    mov ah, 1
    int 0x16
    jz .done
    mov ah, 0
    int 0x16
    jmp .loop
.done:
    ret

freeze_current_line:
    mov al, [shell_row]
    mov ah, 0
    imul ax, 160
    add ax, 14 * 2
    mov di, ax
    mov si, cmd_buffer
.loop:
    lodsb
    cmp al, 0
    je .cls_tail
    mov ah, 0x0E
    mov [gs:di], ax
    add di, 2
    jmp .loop
.cls_tail:
    mov word [gs:di], 0x0720
    ret

print_shell_response:
    inc byte [shell_row]
    cmp byte [shell_row], 22
    jl .do_print
    mov byte [shell_row], 2
    call clear_left_shell
.do_print:
    mov al, [shell_row]
    mov ah, 0
    imul ax, 160
    add ax, 2 * 2
    mov di, ax
    mov ah, 0x07            
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [gs:di], ax
    add di, 2
    jmp .loop
.done:
    ret

clear_left_shell:
    mov bx, 2
.row_loop:
    mov cx, 0
.col_loop:
    mov ax, bx
    imul ax, 160
    mov dx, cx
    shl dx, 1
    add ax, dx
    mov di, ax
    mov word [gs:di], 0x0720
    inc cx
    cmp cx, 39
    jl .col_loop
    inc bx
    cmp bx, 22
    jl .row_loop
    ret

draw_shell_prompt:
    mov al, [shell_row]
    mov ah, 0
    imul ax, 160
    add ax, 1 * 2
    mov di, ax
    mov si, shell_prompt_str
    mov ah, 0x0C            
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [gs:di], ax
    add di, 2
    jmp .loop
.done:
    ret

redraw_shell_input:
    mov al, [shell_row]
    mov ah, 0
    imul ax, 160
    add ax, 14 * 2
    mov di, ax

    mov cx, 20
.cls_line:
    mov word [gs:di], 0x0720
    add di, 2
    loop .cls_line

    mov al, [shell_row]
    mov ah, 0
    imul ax, 160
    add ax, 14 * 2
    mov di, ax
    mov si, cmd_buffer
.print_loop:
    lodsb
    cmp al, 0
    je .draw_cursor
    mov ah, 0x0E            
    mov [gs:di], ax
    add di, 2
    jmp .print_loop
.draw_cursor:
    mov word [gs:di], 0x0F5F
    ret

draw_split_screen:
    mov ax, cs
    mov es, ax

    xor di, di
    mov cx, 80*25
.cls:
    mov word [gs:di], 0x0720
    add di, 2
    loop .cls

    mov bx, 0
.line_loop:
    mov ax, bx
    imul ax, 160
    add ax, 40 * 2
    mov di, ax
    mov word [gs:di], 0x08B3
    inc bx
    cmp bx, 24
    jl .line_loop

    mov di, 24 * 160
    mov cx, 80
.bot_loop:
    mov word [gs:di], 0x1F20
    add di, 2
    loop .bot_loop

    mov si, status_str
    mov di, (24 * 160) + (2 * 2)
    call write_tui_str_color

    mov si, left_title
    mov di, (0 * 160) + (2 * 2)
    call write_tui_str

    mov byte [shell_row], 2
    call draw_shell_prompt
    call redraw_shell_input
    call draw_right_files
    call update_focus_status
    ret

; ====================================================
; 右侧系统模块列表
; ====================================================
handle_file_manager:
    cmp ah, 0x48
    je .move_up
    cmp ah, 0x50
    je .move_down
    jmp shell_loop
.move_up:
    cmp byte [file_select], 0
    jle shell_loop
    dec byte [file_select]
    call draw_right_files
    jmp shell_loop
.move_down:
    cmp byte [file_select], 3
    jge shell_loop
    inc byte [file_select]
    call draw_right_files
    jmp shell_loop

draw_right_files:
    mov si, right_title
    mov di, (0 * 160) + (42 * 2)
    call write_tui_str

    mov bx, 0
.file_loop:
    mov ax, bx
    add ax, 2
    imul ax, 160
    add ax, 42 * 2
    mov di, ax

    mov al, [file_select]
    cmp bl, al
    je .selected
    mov byte [file_attr], 0x07
    jmp .print_fn
.selected:
    mov byte [file_attr], 0x70

.print_fn:
    push bx
    imul bx, 24             
    add bx, file_list
    mov si, bx
    call write_tui_str_attr
    pop bx

    inc bx
    cmp bx, 4
    jl .file_loop
    ret

update_focus_status:
    cmp byte [active_focus], 0
    jne .right_active
    mov si, focus_left_str
    mov di, (24 * 160) + (50 * 2)
    call write_tui_str_color
    ret
.right_active:
    mov si, focus_right_str
    mov di, (24 * 160) + (50 * 2)
    call write_tui_str_color
    ret

write_tui_str:
    mov ah, 0x0F
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [gs:di], ax
    add di, 2
    jmp .loop
.done:
    ret

write_tui_str_color:
    mov ah, 0x1F
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [gs:di], ax
    add di, 2
    jmp .loop
.done:
    ret

write_tui_str_attr:
    mov ah, [file_attr]
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [gs:di], ax
    add di, 2
    jmp .loop
.done:
    ret

streq:
    pusha
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_equal
    cmp al, 0
    je .equal
    inc si
    inc di
    jmp .loop
.equal:
    popa
    stc
    ret
.not_equal:
    popa
    clc
    ret

; ====================================================
; 3D 渲染器模块
; ====================================================
do_3d_demo:
    mov ax, 0x0013
    int 0x10
    mov ax, 0xA000
    mov es, ax
    mov word [angle], 0

.render_frame:
    xor di, di
    mov cx, 64000/2
    xor ax, ax
    rep stosw

    add word [angle], 4
    cmp word [angle], 360
    jl .draw_shape
    mov word [angle], 0

.draw_shape:
    mov cx, 160
    mov dx, 60
    mov si, 220
    mov di, 140
    call draw_line
    mov cx, 220
    mov dx, 140
    mov si, 100
    mov di, 140
    call draw_line
    mov cx, 100
    mov dx, 140
    mov si, 160
    mov di, 60
    call draw_line

    mov ax, [angle]
    mov bx, 50
    imul bx
    mov bx, 100
    idiv bx
    add ax, 160

    mov bx, 100 * 320
    add bx, ax
    mov byte [es:bx], 0x0C 

    mov cx, 0x2FFF
.delay:
    nop
    loop .delay

    mov ah, 1
    int 0x16
    jz .render_frame

    mov ah, 0
    int 0x16
    mov ax, 0x0003
    int 0x10
    mov ax, cs
    mov es, ax
    ret

draw_line:
    pusha
    mov bx, dx
    imul bx, 320
    add bx, cx
    mov byte [es:bx], 0x09
    popa
    ret

; ====================================================
; 数据段定义
; ====================================================
active_focus:     db 0
file_select:      db 0
file_attr:        db 0x07
angle:            dw 0
shell_row:        db 2
cmd_len:          db 0
logo_color:       db 0x0B
cmd_buffer:       times 24 db 0

; 修正后的正向 ZZX OS 宽体大写字符画
logo_line1: db " _______  _______ __   __    _____   _______ ", 0
logo_line2: db "|___    ||___    |\ \ / /   / __  \ |       |", 0
logo_line3: db "   /   /    /   /  \ V /   | |  | | |  _____|", 0
logo_line4: db "  /   /    /   /    / _ \  | |  | | | |_____ ", 0
logo_line5: db " /_______//_______/ /_/ \_\ \_____/  |_______|", 0
logo_text:  db "CORE SYSTEM INITIALIZING...", 0

msg_halt:   db "SYSTEM HALTED. SAFE TO POWER OFF.", 13, 10, 0

; POST 自检数组 (15项)
post_messages:
    dw p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15

p1:  db "[OK] Central Processor Unit... Intact", 13, 10, 0
p2:  db "[OK] Memory Controller... 640K Base", 13, 10, 0
p3:  db "[OK] Extended Memory... 15MB Block", 13, 10, 0
p4:  db "[OK] Storage Interface Bus... Linked", 13, 10, 0
p5:  db "[OK] Video Graphics Array... 0xB800", 13, 10, 0
p6:  db "[OK] Keyboard Interrupt Vector... 0x16", 13, 10, 0
p7:  db "[OK] RTC Clock Sync... Valid", 13, 10, 0
p8:  db "[OK] Core Instruction Set... x86", 13, 10, 0
p9:  db "[OK] Thermal Sensors... Nominal", 13, 10, 0
p10: db "[OK] Data Blocks Encryption... Off", 13, 10, 0
p11: db "[OK] Sub-system Linkage... Active", 13, 10, 0
p12: db "[OK] IO Ports Mapping... Resolved", 13, 10, 0
p13: db "[OK] Kernel Segment CS:DS:ES... Match", 13, 10, 0
p14: db "[OK] Security Bypass Module... Loaded", 13, 10, 0
p15: db "[OK] Booting ZZX CORE OS...", 13, 10, 0

left_title:       db "[ MAIN CORE CONSOLE ]", 0
right_title:      db "[ STORAGE BLOCKS MAP ]", 0
shell_prompt_str: db "[ZZX-CORE]>> ", 0

status_str:       db "[ALT+B] Toggle View Target", 0
focus_left_str:   db "TARGET: [CONSOLE]", 0
focus_right_str:  db "TARGET: [STORAGE]", 0

cmd_guide:    db "guide", 0
cmd_wipe:     db "wipe", 0
cmd_render:   db "render", 0
cmd_info:     db "info", 0
cmd_sysver:   db "sysver", 0
cmd_memory:   db "memory", 0
cmd_storage:  db "storage", 0
cmd_network:  db "network", 0
cmd_process:  db "process", 0
cmd_hardware: db "hardware", 0
cmd_datetime: db "datetime", 0
cmd_diag:     db "diag", 0
cmd_beep:     db "beep", 0
cmd_lock:     db "lock", 0
cmd_poweroff: db "poweroff", 0

res_guide:    db "Cmd: guide,wipe,render,info,sysver...", 0
res_info:     db "OS: ZZX CORE ARCHITECTURE", 0
res_sysver:   db "Build: KRNL-9042-XETA", 0
res_memory:   db "RAM: 640K BASE / 15M EXT", 0
res_storage:  db "BLK0: 1.44MB [READ ONLY]", 0
res_network:  db "NET: OFFLINE. No Interface.", 0
res_process:  db "PID0: KERNEL | PID1: SHELL", 0
res_hardware: db "CPU: x86 Emulated Engine", 0
res_datetime: db "RTC: CLOCK SYNC ESTABLISHED", 0
res_diag:     db "DIAG: ALL SYSTEMS GREEN", 0
res_beep:     db "BEEP: Audio signal sent.", 0
res_unknown:  db "ERR: Unknown directive.", 0

file_list:
    db "[BLK0:\SYS\KRNL.SYS]", 0, 0, 0, 0 
    db "[BLK0:\BIN\RNDR.EXE]", 0, 0, 0, 0 
    db "[BLK0:\CFG\CORE.INI]", 0, 0, 0, 0 
    db "[BLK0:\DAT\SECU.LOG]", 0, 0, 0, 0