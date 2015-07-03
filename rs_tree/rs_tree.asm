virtual at rbx
    ri rsitem
end virtual

virtual at rsi
    nmtvcd NMTVCUSTOMDRAW
end virtual

proc RSTree_Item_Display
    frame
        invoke SendMessageW, [hCurrTreeControl], TVM_GETNEXTITEM, TVGN_PREVIOUS, [nmtvcd.nmcd.dwItemSpec]
        test rax, rax
        jz @f
            mov [treeItem.hItem], rax
            mov [treeItem.mask], TVIF_PARAM
            invoke SendMessageW, [hCurrTreeControl], TVM_GETITEM, 0, treeItem
            errorCheck
            mov rax, [treeItem.lParam]
            virtual at rax
                .pri rsitem
            end virtual
            mov rcx, [.pri.address]
            mov edx, [.pri.size]
            add rcx, rdx
            mov [ri.address], rcx
        @@:

        stdcall RSTree_Item_Draw_Address
        stdcall RSTree_Item_Draw_Offset

        mov rcx, [hRemoteProcess]
        test rcx, rcx
        jz .ret

        xor eax, eax
        mov [remoteBuffer], rax
        invoke ReadProcessMemory, rcx, [ri.address], remoteBuffer, [ri.size], remoteRead

    ;       mov eax, [ri.type]
    ;       cmp eax, ...
    ;       je ...
    ;       .t_unknown:
            stdcall RSTree_Item_Draw_Chars
            stdcall RSTree_Item_Draw_Bytes
            stdcall RSTree_Item_Draw_SWord
            stdcall RSTree_Item_Draw_Float
            stdcall RSTree_Item_Draw_Double
        .ret:
    endf
    ret
endp

proc RSTree_Item_Draw margin, color
    local .itemRect RECT
    frame
        mov [margin], rcx
        invoke SetTextColor, [hTreeDCMem], rdx
        invoke DrawTextA,\
            [hTreeDCMem],\               ; hDC
            szRSItemBuffer,\             ; lpchText
            -1,\                         ; nCount
            itemDrawingRect,\            ; lpRect
            DT_LEFT or DT_BOTTOM or DT_SINGLELINE or DT_NOPREFIX ; uFormat
        errorCheck
        invoke DrawTextA,\
            [hTreeDCMem],\               ; hDC
            szRSItemBuffer,\             ; lpchText
            -1,\                         ; nCount
            addr .itemRect,\             ; lpRect
            DT_LEFT or DT_BOTTOM or DT_SINGLELINE or DT_NOPREFIX or DT_CALCRECT ; uFormat
        errorCheck
        mov eax, [.itemRect.right]
        sub eax, [.itemRect.left]
        add eax, dword[margin]
        add [itemDrawingRect.left], eax
    endf
    ret
endp

proc RSTree_Item_Draw_Address
    frame
        mov r8d, dword[ri.address + 4]
        mov r9d, dword[ri.address + 0]
        cinvoke sprintf, szRSItemBuffer, [pszFmtAddress], r8, r9
        stdcall RSTree_Item_Draw, [marginAddress], [colorAddress]
    endf
    ret
endp

proc RSTree_Item_Draw_Offset
    frame
        movzx r8, [ri.offset]
        cinvoke sprintf, szRSItemBuffer, szFmtWord, r8
        stdcall RSTree_Item_Draw, [marginOffset], [colorOffset]
    endf
    ret
endp

proc RSTree_Item_Draw_Chars uses r15
    frame
        xor r15, r15
        .loop:
            cmp r15, [remoteRead]
            jb @f
                mov dword[szRSItemBuffer], '?'
                jmp .draw
            @@:
                movzx eax, byte[remoteBuffer + r15]
                mov ecx, '.'
                cmp al, ' '
                cmovb eax, ecx
                cmp al, '~'
                cmova eax, ecx
                cmp al, '`'
                cmove eax, ecx
                mov dword[szRSItemBuffer], eax
            .draw:
                cmp r15, 4
                jne @f
                    mov eax, [marginMiddle]
                    add [itemDrawingRect.left], eax
                @@:
                stdcall RSTree_Item_Draw, [marginChar], [colorChar]
                inc r15
                cmp r15d, [ri.size]
                jb .loop
        mov eax, [marginChars]
        add [itemDrawingRect.left], eax
        ret
    endf
endp

proc RSTree_Item_Draw_Bytes uses r15
    frame
        xor r15, r15
        .loop:
            cmp r15, [remoteRead]
            jb @f
                mov dword[szRSItemBuffer], '??'
                jmp .draw
            @@:
                movzx r8, byte[remoteBuffer + r15]
                cinvoke sprintf, szRSItemBuffer, szFmtByte, r8
            .draw:
                cmp r15, 4
                jne @f
                    mov eax, [marginMiddle]
                    add [itemDrawingRect.left], eax
                @@:
                stdcall RSTree_Item_Draw, [marginByte], [colorByte]
                inc r15
                cmp r15d, [ri.size]
                jb .loop
        mov eax, [marginBytes]
        add [itemDrawingRect.left], eax
    endf
    ret
endp

proc RSTree_Item_Draw_SWord
    frame
        mov r8d, dword[remoteBuffer + 4]
        mov r9d, dword[remoteBuffer + 0]
        cinvoke sprintf, szRSItemBuffer, [pszFmtSWord], r8, r9
        stdcall RSTree_Item_Draw, [marginValue], [colorValue]
    endf
    ret
endp

proc RSTree_Item_Draw_Float
    frame
        cvtss2sd xmm0, dword[remoteBuffer + 0]
        cvtss2sd xmm1, dword[remoteBuffer + 4]
        movq r8, xmm0
        movq r9, xmm1
        cinvoke sprintf, szRSItemBuffer, [pszFmtFloat], r8, r9
        stdcall RSTree_Item_Draw, [marginValue], [colorValue]
    endf
    ret
endp

proc RSTree_Item_Draw_Double
    frame
        movsd xmm0, qword[remoteBuffer]
        cinvoke sprintf, szRSItemBuffer, szFmtDouble, qword[remoteBuffer]
        stdcall RSTree_Item_Draw, [marginValue], [colorValue]
    endf
    ret
endp

proc RSTree_Append_Item
    frame
        invoke SendMessageW, TVM_GETNEXTITEM, TVGN_CARET, 0
        test rax, rax

        mov rcx, TVI_ROOT

        jz @f
            invoke SendMessageW, TVM_GETNEXTITEM, TVGN_PARENT, 0
            test rax, rax
            mov rcx, TVI_ROOT
            cmovnz rcx, rax
        @@:

        mov rdx, TVI_LAST
        stdcall Tree_AddItem, rcx, rdx
    endf
    ret
endp

