[ORG 0x7C00]
[BITS 16]

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00          ; 初始化栈指针

    ; 1. 清屏并设置为标准文本模式
    mov ax, 0x0003
    int 0x10

    ; 2. 显示 Boot 日志
    mov si, boot_msg
    call print_string

    mov si, loading_msg
    call print_string

    ; 3. 重置软盘控制器
    mov ah, 0
    mov dl, 0
    int 0x13

    ; 4. 安全读取 18 个扇区 (完整读完 Cylinder 0, Head 0)
    mov ax, 0x1000
    mov es, ax
    xor bx, bx              ; 目标地址 0x1000:0000

    mov di, 3               ; 重试 3 次
read_disk:
    mov ah, 0x02
    mov al, 18              ; 读 18 个扇区（9KB，对我们的内核绰绰有余）
    mov ch, 0               ; 柱面 0
    mov cl, 2               ; 从 2 号扇区开始
    mov dh, 0               ; 磁头 0
    mov dl, 0               ; 驱动器 A
    int 0x13
    jnc read_success        ; 无错则跳转

    ; 失败重试
    dec di
    jnz read_disk

    ; 重试完依然失败显示错误
    mov si, err_msg
    call print_string
    hlt

read_success:
    ; 跳转到内核入口
    jmp 0x1000:0000

print_string:
    mov ah, 0x0E
    mov bh, 0
    mov bl, 0x07
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    ret

boot_msg:    db "[  0.000000] ZZX Bootloader v1.0.0", 0x0D, 0x0A, 0
loading_msg: db "[  0.102412] Loading ZZX Kernel from disk...", 0x0D, 0x0A, 0
err_msg:     db "[  FAILED  ] Disk read error!", 0x0D, 0x0A, 0

times 510 - ($ - $$) db 0
dw 0xAA55