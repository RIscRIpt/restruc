;Idea from http://habrahabr.ru/post/247425/
;Doc: http://blogs.msdn.com/b/oldnewthing/archive/2010/10/22/10079192.aspx
format Binary as 'ico'

macro CompileIco [filename, w, h, bpp] {
    local count
    common
        count = 0
    forward
        count = count + 1
    common
        dw 0 ; reserved, must be 0
        dw 1 ; icon type, must be 1
        dw count
    forward
        local file_start, file_end, t
        db w
        db h
        t = 1 shl bpp
        if t >= 8
            t = 0
        end if
        db t
        db 0 ;reserved, must be 0
        dw 1 ;planes
        dw bpp
        dd file_end - file_start ;length
        dd file_start
        count = count + 1
    forward
        file_start:
        file filename
        file_end:
}

CompileIco \
    'icon.png', 48, 48, 8

