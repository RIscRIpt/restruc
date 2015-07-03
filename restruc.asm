format PE64 GUI

include 'win64w.inc'
include 'commctrl.inc'
include 'exmacro/exmacro.inc'

entry main

                macro GetDlgItemHwnd hwnd, [id, dest] {
                    forward
                        invoke GetDlgItem, hwnd, id
                        errorCheck
                        mov [dest], rax
                }

struct rsitem
    title           db 48 dup ?
    address         dq ?
    offset          dw ?
    type            dw ?
    size            dd ?
ends

struct PROCESSENTRY32W
    dwSize              dd ?
    cntUsage            dd ?
    th32ProcessID       dd ?
                        dd ? ;align pointer
    th32DefaultHeapID   dq ?
    th32ModuleID        dd ?
    cntThreads          dd ?
    th32ParentProcessID dd ?
    pcPriClassBase      dd ?
    dwFlags             dd ?
    szExeFile           du MAX_PATH dup ?
                        dd ? ;align struct
ends

TH32CS_SNAPHEAPLIST = 0x00000001
TH32CS_SNAPPROCESS  = 0x00000002
TH32CS_SNAPTHREAD   = 0x00000004
TH32CS_SNAPMODULE   = 0x00000008
TH32CS_SNAPMODULE32 = 0x00000010
TH32CS_SNAPALL      = TH32CS_SNAPHEAPLIST or TH32CS_SNAPPROCESS or TH32CS_SNAPTHREAD or TH32CS_SNAPMODULE
TH32CS_INHERIT      = 0x80000000

PROCESS_QUERY_LIMITED_INFORMATION = 0x1000


macro errorCheck cond=e, val=0, reg=rax, handler=errorHandler {
    if val
        cmp reg, val
        ;je handler
    else
        test reg, reg
        ;jz handler
    end if
    if cond eq e
        jz handler ;jz == je (Checks ZERO flag)
    else if cond eq ne
        jnz handler ;jnz == jne (Checks ZERO flag)
    else
        display 'errorCheck: invalid cond argument!', 13, 10
        err
    end if
}

macro malloc n {
    invoke HeapAlloc, [hProcessHeap], HEAP_ZERO_MEMORY, n
    errorCheck
}

macro free p {
    invoke HeapFree, [hProcessHeap], 0, p
    errorCheck
}

section '.code' code readable executable
    errorHandler:
        stdcall ShowLastError, HWND_DESKTOP
        invoke ExitProcess, rax
        int3

    proc ShowLastError hWndOwner
        local .buffer dq ?
        local .error dq ?
        frame
            mov [hWndOwner], rcx
            invoke GetLastError
            mov [.error], rax
            invoke FormatMessageW,\
                FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS,\
                0,\
                rax,\
                0,\
                addr .buffer,\
                0,\
                0
            invoke MessageBoxW, [hWndOwner], [.buffer], 0, MB_ICONHAND
            invoke LocalFree, [.buffer]
            mov rax, [.error]
        endf
        ret
    endp

    proc main
        and rsp, -16
        frame
            invoke GetProcessHeap
            errorCheck
            mov [hProcessHeap], rax

            invoke InitCommonControlsEx, iccex
            errorCheck

            invoke CreateFontW,\
                9,\                        ;int nHeight,
                6,\                        ;int nWidth,
                0,\                        ;int nEscapement,
                0,\                        ;int nOrientation,
                FW_NORMAL,\                ;int fnWeight,
                0,\                        ;DWORD fdwItalic,
                0,\                        ;DWORD fdwUnderline,
                0,\                        ;DWORD fdwStrikeOut,
                OEM_CHARSET,\              ;DWORD fdwCharSet,
                OUT_DEFAULT_PRECIS,\       ;DWORD fdwOutputPrecision,
                CLIP_DEFAULT_PRECIS,\      ;DWORD fdwClipPrecision,
                DEFAULT_QUALITY,\          ;DWORD fdwQuality,
                FIXED_PITCH or FF_MODERN,\  ;DWORD fdwPitchAndFamily,
                wcsTerminal                ;LPCTSTR lpszFace
            errorCheck
            mov [hFontTerminal], rax

            stdcall MakeBrushes

            invoke DialogBoxParamW,\
                0,\                 ;hInstance
                RSRC_MAIN_DIALOG,\  ;lpTemplateName
                HWND_DESKTOP,\      ;hWndParent
                MainDialogProc,\    ;lpDialogFunc
                0                   ;dwInitParam

            invoke DeleteObject, [hFontTerminal]

            invoke ExitProcess, 0
        endf
    endp

    ;TODO: delete brushes @ end
    proc MakeBrushes
        frame
            macro .make [color, handle] {
                forward
                    mov rcx, [handle]
                    test rcx, rcx
                    jz @f
                        invoke DeleteObject, rcx
                    @@:
                forward
                    invoke CreateSolidBrush, [color]
                    errorCheck
                    mov [handle], rax
            }
            .make \
                colorBackground,   hBrushBackground,\
                colorSelectedItem, hBrushSelectedItem
            purge .make
        endf
        ret
    endp

    proc SetFont hWnd, font
        mov r8, rdx
        xor r9, r9
        mov edx, WM_SETFONT
        invoke SendMessageW, rcx, rdx, r8, r9
        ;WM_SETFONT doesn't return a value
        xor eax, eax
        inc eax
        ret
    endp

    proc MainDialogProc uses rbx rsi rdi, hWnd, uMsg, wParam, lParam
        frame
            cmp edx, WM_NOTIFY
            je .wm_notify
            cmp edx, WM_SIZING
            je .wm_sizing
            cmp edx, WM_SIZE
            je .wm_size
            cmp edx, WM_COMMAND
            je .wm_command
            cmp edx, WM_INITDIALOG
            je .wm_initdialog
            cmp edx, WM_CLOSE
            je .wm_close
            jmp .finish

            .wm_notify:
                virtual at r9
                    .nmhdr NMHDR
                end virtual
                mov rax, [.nmhdr.idFrom]
                cmp rax, RSRC_TAB_CONTROL
                jne .finish
                ;.wm_n_tab_control:
                    cmp [.nmhdr.code], TCN_SELCHANGE
                    jne .finish
                    ;.wm_n_tcn_selchange:
                        invoke ShowWindow, [hCurrTreeDialog], SW_HIDE
                        invoke SendMessageW, [hTabControl], TCM_GETCURSEL, 0, 0
                        mov rcx, [hTreeDialogs + rax * 8]
                        mov rdx, [hTreeControls + rax * 8]
                        mov [hCurrTreeDialog], rcx
                        mov [hCurrTreeControl], rdx
                        invoke ShowWindow, rcx, SW_SHOW
                        invoke PostMessageW, [hMainDialog], WM_SIZE, 0, 0
                        errorCheck
                        jmp .processed

            .wm_sizing:
            .wm_size:
                invoke GetClientRect, rcx, windowRect
                errorCheck
                invoke SendMessageW, [hTbControl], TB_AUTOSIZE, 0, 0
                invoke GetWindowRect, [hTbControl], tabRect
                errorCheck
                movsxd r9, [tabRect.bottom]
                sub r9d, [tabRect.top]
                sub [windowRect.bottom], r9d
                invoke SetWindowPos, [hTabControl], 0, 0, r9, [windowRect.right], [windowRect.bottom], SWP_NOZORDER
                errorCheck
                invoke SendMessageW, [hTabControl], TCM_ADJUSTRECT, 0, windowRect
                mov rbx, [hCurrTreeDialog]
                mov rdi, [hCurrTreeControl]
                test rbx, rbx
                jz .processed
                test rdi, rdi
                jz .processed
                ;jz @f
                    movsxd r8,  [windowRect.left]
                    movsxd r9,  [windowRect.top]
                    movsxd r10, [windowRect.right]
                    movsxd r11, [windowRect.bottom]
                    sub r10, r8
                    sub r11, r9
                    invoke SetWindowPos, rbx, 0, r8, r9, r10, r11, SWP_NOZORDER
                    errorCheck
                    invoke GetClientRect, rbx, treeRect
                    errorCheck
                    movsxd r8,  [treeRect.left]
                    movsxd r9,  [treeRect.top]
                    movsxd r10, [treeRect.right]
                    movsxd r11, [treeRect.bottom]
                    sub r10, r8
                    sub r11, r9
                    invoke SetWindowPos, rdi, 0, r8, r9, r10, r11, SWP_NOZORDER
                    errorCheck
                ;@@:
                    jmp .processed

            .wm_command:
                test r9, r9
                jnz .finish
                mov eax, r8d
                shr eax, 16
                test eax, eax
                jnz .finish
                ;.menu:
                    movzx eax, r8w
                    cmp eax, IDM_MAIN_MIN
                    jb .finish
                    cmp eax, IDM_MAIN_MAX
                    jae .finish
                    call qword[Menu_Main_Handler_List + eax * 8]
                    jmp .processed

            .wm_initdialog:
                mov [hMainDialog], rcx
                mov rbx, rcx

                GetDlgItemHwnd rbx, \
                    RSRC_TB_CONTROL,    hTbControl,\
                    RSRC_TAB_CONTROL,   hTabControl

                stdcall SetFont, rbx, [hFontTerminal]
                invoke EnumChildWindows, rbx, SetFont, [hFontTerminal]

                stdcall Class_New

                jmp .processed

            .wm_close:
                invoke EndDialog, rcx, 0
                errorCheck
                ;jmp .processed

            .processed:
                xor eax, eax
                inc eax
                jmp @f
            .finish:
                xor eax, eax
            @@:
        endf
        ret
    endp

    proc TreeDialogProc uses rbx rsi rdi r12 r13 r14 r15, hWnd, uMsg, wParam, lParam
        frame
            cmp edx, WM_NOTIFY
            je .wm_notify
            cmp edx, WM_SIZING
            je .wm_sizing
            cmp edx, WM_SIZE
            je .wm_size
            cmp edx, WM_INITDIALOG
            je .wm_initdialog
            cmp edx, WM_CLOSE
            je .wm_close
            jmp .finish

            .wm_notify:
                mov [hWnd], rcx
                virtual at r9
                    .nmhdr NMHDR
                end virtual
                cmp [.nmhdr.idFrom], RSRC_TREE_CONTROL
                jne .finish
                ;.wm_n_tree_ctrl:
                    mov eax, [.nmhdr.code]
                    cmp eax, NM_CUSTOMDRAW
                    je .wm_ntc_nm_custromdraw
                    cmp eax, TVN_DELETEITEM
                    je .wm_ntc_tvn_deleteitem
                    cmp eax, TVN_KEYDOWN
                    jne .finish
                        virtual at r9
                            .nmtvkd NMTVKEYDOWN
                        end virtual
                        movzx eax, [.nmtvkd.wVKey]
                        mov rax, [RSTree_KeyParserTable + eax * 8]
                        test rax, rax
                        jz .finish
                        push .finish
                        jmp rax

                    .wm_ntc_tvn_deleteitem:
                        virtual at r9
                            .nmtv NMTREEVIEW
                        end virtual
                        mov r8, [.nmtv.itemOld.lParam]
                        test r8, r8
                        jz @f
                            free r8
                        @@:
                        jmp .finish ;return value is ignored

                    .wm_ntc_nm_custromdraw:
                        mov rsi, r9
                        virtual at rsi
                            .nmtvcd NMTVCUSTOMDRAW
                        end virtual
                        mov eax, [.nmtvcd.nmcd.dwDrawStage]
                        cmp eax, CDDS_ITEMPREPAINT
                        je .wm_ntc_nm_cd_itemprepaint
                        cmp eax, CDDS_PREPAINT
                        je .wm_ntc_nm_cd_prepaint
                        cmp eax, CDDS_POSTPAINT
                        je .wm_ntc_nm_cd_postpaint
                        jmp .finish

                        .wm_ntc_nm_cd_prepaint:
                            invoke CreateCompatibleDC, [.nmtvcd.nmcd.hdc]
                            errorCheck
                            mov [hTreeDCMem], rax

                            movdqu xmm0, [.nmtvcd.nmcd.rc]
                            movsxd r9,  [.nmtvcd.nmcd.rc.left]
                            movsxd r10, [.nmtvcd.nmcd.rc.top]
                            movsxd rdx, [.nmtvcd.nmcd.rc.right]
                            movsxd r8,  [.nmtvcd.nmcd.rc.bottom]
                            movdqa [treeDrawingRect], xmm0
                            sub rdx, r9
                            sub r8,  r10
                            invoke CreateCompatibleBitmap, [.nmtvcd.nmcd.hdc], rdx, r8
                            errorCheck
                            mov [hTreeBMMem], rax

                            invoke SelectObject, [hTreeDCMem], [hTreeBMMem]
                            errorCheck

                            invoke SelectObject, [hTreeDCMem], [hFontTerminal]
                            errorCheck

                            movsxd rdx, [.nmtvcd.nmcd.rc.left]
                            movsxd r8, [.nmtvcd.nmcd.rc.top]
                            neg rdx
                            neg r8
                            invoke OffsetViewportOrgEx, [hTreeDCMem], rdx, r8, treeOldDrOrig
                            errorCheck

                            invoke FillRect, [hTreeDCMem], addr .nmtvcd.nmcd.rc, [hBrushBackground]
                            errorCheck

                            mov ebx, CDRF_NOTIFYITEMDRAW or CDRF_NOTIFYPOSTPAINT
                            jmp .wm_ntc_nm_cd_processed

                        .wm_ntc_nm_cd_postpaint:
                            invoke SetViewportOrgEx, [hTreeDCMem], [treeOldDrOrig.x], [treeOldDrOrig.y], 0
                            errorCheck
                            movsxd rdx, [treeDrawingRect.left]
                            movsxd r8,  [treeDrawingRect.top]
                            movsxd r9,  [treeDrawingRect.right]
                            movsxd r10, [treeDrawingRect.bottom]
                            sub r9, rdx
                            sub r10, r8
                            invoke BitBlt, [.nmtvcd.nmcd.hdc], rdx, r8, r9, r10, [hTreeDCMem], 0, 0, SRCCOPY
                            errorCheck
                            invoke DeleteObject, [hTreeBMMem]
                            errorCheck
                            invoke DeleteDC, [hTreeDCMem]
                            errorCheck
                            jmp .processed

                        .wm_ntc_nm_cd_itemprepaint:
                            movdqu xmm0, [.nmtvcd.nmcd.rc]
                            movdqa [itemDrawingRect], xmm0

                            invoke SetBkMode, [hTreeDCMem], TRANSPARENT
                            test [.nmtvcd.nmcd.uItemState], CDIS_SELECTED
                            jz @f
                                invoke FillRect, [hTreeDCMem], addr .nmtvcd.nmcd.rc, [hBrushSelectedItem]
                            @@:

                            mov rbx, [.nmtvcd.nmcd.lItemlParam]
                            stdcall RSTree_Item_Display

                            mov ebx, CDRF_SKIPDEFAULT
                            ;jmp .wm_ntc_nm_cd_processed

                        .wm_ntc_nm_cd_processed:
                            invoke SetLastError, 0
                            invoke SetWindowLongPtr, [hWnd], DWLP_MSGRESULT, ebx
                            test rax, rax
                            jz @f
                                invoke GetLastError
                                test rax, rax
                                jnz errorHandler
                            @@:
                            mov eax, ebx
                            jmp .done

            .wm_sizing:
            .wm_size:
                jmp .processed

            .wm_initdialog:
                mov [hWnd], rcx
                stdcall SetFont, rcx, [hFontTerminal]
                invoke EnumChildWindows, [hWnd], SetFont, [hFontTerminal]
                invoke GetDlgItem, [hWnd], RSRC_TREE_CONTROL
                errorCheck
                invoke SendMessageW, rax, TVM_SETEXTENDEDSTYLE, 0, TVS_EX_DOUBLEBUFFER
                errorCheck ne, 0
                jmp .processed

            .wm_close:
                invoke EndDialog, rcx, 0
                errorCheck
                ;jmp .processed

            .processed:
                xor eax, eax
                inc eax
                jmp .done
            .finish:
                xor eax, eax
            .done:
        endf
        ret
    endp

    proc ProcDialogProc hWnd, uMsg, wParam, lParam
        frame
            mov [hWnd], rcx

            cmp edx, WM_SIZING
            je .wm_sizing
            cmp edx, WM_SIZE
            je .wm_size
            cmp edx, WM_NOTIFY
            je .wm_notify
            cmp edx, WM_INITDIALOG
            je .wm_initdialog
            cmp edx, WM_CLOSE
            je .wm_close
            jmp .finish

            .wm_sizing:
            .wm_size:
                invoke GetClientRect, [hWnd], windowRect
                errorCheck
                invoke GetDlgItem, [hWnd], RSRC_PD_LIST
                errorCheck
                sub [windowRect.bottom], 32
                invoke SetWindowPos, rax, 0, 0, 0, [windowRect.right], [windowRect.bottom], SWP_NOZORDER
                invoke SendMessageW, [hPDList], LVM_SETCOLUMNWIDTH, 2, LVSCW_AUTOSIZE_USEHEADER
                jmp .processed

            .wm_notify:
                virtual at r9
                    .nmhdr NMHDR
                end virtual
                mov rax, [.nmhdr.idFrom]
                cmp rax, RSRC_PD_LIST
                jne .finish
                ;.wm_n_list:
                    cmp [.nmhdr.code], NM_DBLCLK
                    jne .finish
                    ;.wm_n_list_dblclk:
                        virtual at r9
                            .nmia NMITEMACTIVATE
                        end virtual
                        mov eax, [.nmia.iItem]
                        mov [listItem.iItem], eax
                        mov [listItem.mask], LVIF_PARAM
                        invoke SendMessageW, [hPDList], LVM_GETITEMW, 0, listItem
                        errorCheck
                        invoke OpenProcess, PROCESS_VM_READ or PROCESS_VM_WRITE or PROCESS_QUERY_LIMITED_INFORMATION, 0, [listItem.lParam]
                        test rax, rax
                        jnz @f
                            stdcall ShowLastError, [hWnd]
                            jmp .processed
                        @@:
                        mov [hRemoteProcess], rax
                        invoke IsWow64Process, rax, isRemoteWOW64
                        errorCheck
                        stdcall ProcSetupFmt
                        jmp .wm_close

            .wm_initdialog:
                GetDlgItemHwnd [hWnd],\
                    RSRC_PD_LIST, hPDList

                stdcall SetFont, [hWnd], [hFontTerminal]
                invoke EnumChildWindows, [hWnd], SetFont, [hFontTerminal]

                invoke SendMessageW, [hPDList], LVM_SETEXTENDEDLISTVIEWSTYLE, 0, LVS_EX_FULLROWSELECT

                mov [lvColumn.mask], LVCF_TEXT
                mov [lvColumn.pszText], wcsPID
                invoke SendMessageW, [hPDList], LVM_INSERTCOLUMNW, 0, lvColumn
                errorCheck e, -1

                mov [lvColumn.pszText], wcsName
                invoke SendMessageW, [hPDList], LVM_INSERTCOLUMNW, 1, lvColumn
                errorCheck e, -1

                mov [lvColumn.pszText], wcsPath
                invoke SendMessageW, [hPDList], LVM_INSERTCOLUMNW, 2, lvColumn
                errorCheck e, -1

                stdcall ProcDialogRefresh

                invoke PostMessageW, [hWnd], WM_SIZE, 0, 0
                errorCheck
                jmp .processed

            .wm_close:
                invoke EndDialog, [hWnd], 0
                errorCheck
                ;jmp .processed

            .processed:
                xor eax, eax
                inc eax
                jmp @f
            .finish:
                xor eax, eax
            @@:
        endf
        ret
    endp


    proc AddTab uses rbx, title
        local .tci TCITEM
        frame
            mov rdx, rcx

            lea rdi, [.tci]
            mov ecx, sizeof.TCITEM / 4
            xor eax, eax
            rep stosd

            mov [.tci.mask], TCIF_TEXT
            mov [.tci.pszText], rdx

            mov rcx, [hCurrTreeDialog]
            test rcx, rcx
            jz @f
                invoke ShowWindow, rcx, SW_HIDE
            @@:

            invoke SendMessageW, [hTabControl], TCM_INSERTITEMW, rax, addr .tci
            errorCheck e, -1
            mov rbx, rax

            invoke LoadResource, 0, tree_dialog
            errorCheck
            invoke CreateDialogIndirectParamW,\
                0,\                 ;hInstance
                rax,\               ;lpTemplate
                [hTabControl],\     ;hWndParent
                TreeDialogProc,\    ;lpDialogFunc
                0                   ;lParamInit
            errorCheck

            mov [hCurrTreeDialog], rax
            mov [hTreeDialogs + rbx * 8], rax

            invoke GetDlgItem, rax, RSRC_TREE_CONTROL
            mov [hCurrTreeControl], rax
            mov [hTreeControls + rbx * 8], rax

            invoke PostMessageW, [hTabControl], TCM_SETCURSEL, rbx, 0
            errorCheck
            invoke PostMessageW, [hMainDialog], WM_SIZE, 0, 0
            errorCheck
        endf
        ret
    endp

    proc AddItem
        local .tvins TVINSERTSTRUCT
        frame
            lea rdi, [.tvins]
            mov ecx, sizeof.TVINSERTSTRUCT / 4
            xor eax, eax
            rep stosd

            mov [.tvins.hInsertAfter], TVI_ROOT
            mov [.tvins.item.mask], TVIF_TEXT or TVIF_PARAM
            mov [.tvins.item.pszText], wcsUnnamed
            mov [.tvins.item.lParam], wcsUnnamed

            invoke SendMessageW, [hCurrTreeControl], TVM_INSERTITEMW, 0, addr .tvins
            errorCheck
        endf
        ret
    endp

    proc Tree_AddItem uses rbx rsi rdi, parent, after
        local .tvins TVINSERTSTRUCT
        frame
            mov [parent], rcx
            mov [after], rdx

            lea rdi, [.tvins]
            mov ecx, sizeof.TVINSERTSTRUCT / 4
            xor eax, eax
            rep stosd

;           cmp [after], TVI_LAST
;           jne @f
;               ;invoke SendMessageW, [hCurrTreeControl], TVM_GETCOUNT
;               invoke SendMessageW, [hCurrTreeControl], TVM_GETNEXTITEM, TVGN_PREVIOUS, [.nmtvcd.nmcd.dwItemSpec]

;           @@:
;           invoke SendMessageW, [hCurrTreeControl], TVM_GETNEXTITEM, TVGN_PREVIOUS, [after]
;           errorCheck
            xor ebx, ebx
            cmp [after], TVI_LAST
            je @f
                mov rax, [after]
                mov [treeItem.hItem], rax
                mov [treeItem.mask], TVIF_PARAM
                invoke SendMessageW, [hCurrTreeControl], TVM_GETITEM, 0, treeItem
                errorCheck
                mov rbx, [treeItem.lParam]
            @@:

            virtual at rbx
                .pri rsitem
            end virtual

            malloc sizeof.rsitem
            virtual at rax
                .ri rsitem
            end virtual

            lea rdi, [.ri.title]
            lea rsi, [szUnnamed]
            mov ecx, sizeof.szUnnamed
            rep movsb

            mov rcx, $$
            test rbx, rbx
            jz @f
                mov rcx, [.pri.address]
                mov edx, [.pri.size]
                add rcx, rdx
            @@:
            mov [.ri.address], rcx
            mov [.ri.size], 8

            mov rcx, [parent]
            mov rdx, [after]
            mov [.tvins.hParent], rcx
            mov [.tvins.hInsertAfter], rdx
            mov [.tvins.item.mask], TVIF_PARAM
            mov [.tvins.item.lParam], rax

            invoke SendMessageW, [hCurrTreeControl], TVM_INSERTITEMW, 0, addr .tvins
            errorCheck
        endf
        ret
    endp

    proc Class_New uses rbx
        frame
            stdcall AddTab, wcsUnnamed
        endf
        ret
    endp

    proc Menu_Main_Handler_IDM_MAIN_FILE_NEW
        invoke MessageBox,0,0,0,0
        ret
    endp
    proc Menu_Main_Handler_IDM_MAIN_FILE_OPEN
        ret
    endp
    proc Menu_Main_Handler_IDM_MAIN_FILE_SAVE
        ret
    endp
    proc Menu_Main_Handler_IDM_MAIN_FILE_SAVEAS
        ret
    endp
    proc Menu_Main_Handler_IDM_MAIN_FILE_ATTACH
        frame
            invoke DialogBoxParamW,\
                0,\                 ;hInstance
                RSRC_PROC_DIALOG,\  ;lpTemplateName
                [hMainDialog],\     ;hWndParent
                ProcDialogProc,\    ;lpDialogFunc
                0                   ;dwInitParam
        endf
        ret
    endp
    proc Menu_Main_Handler_IDM_MAIN_FILE_DETACH
        ret
    endp
    proc Menu_Main_Handler_IDM_MAIN_EXIT
        ret
    endp
    proc Menu_Main_Handler_IDM_MAIN_CLS_NEW
        stdcall Class_New
        ret
    endp
    proc Menu_Main_Handler_IDM_MAIN_CLS_OPEN
        ret
    endp
    proc Menu_Main_Handler_IDM_MAIN_CLS_DELNOTUSED
        ret
    endp

    proc ProcDialogRefresh uses rbx rsi rdi r12
        locals
            .pe PROCESSENTRY32W
            .item LVITEM
            .buffer du 256 dup ?
            .len dq ?
        endl
        frame
            lea rdi, [.pe]
            xor eax, eax
            mov ecx, (sizeof.PROCESSENTRY32W + sizeof.LVITEM) / 4
            rep stosd

            mov [.item.iGroupId], I_GROUPIDNONE

            invoke SendMessageW, [hPDList], LVM_DELETEALLITEMS, 0, 0
            errorCheck
            xor esi, esi

            invoke CreateToolhelp32Snapshot, TH32CS_SNAPPROCESS, 0
            errorCheck
            mov rbx, rax

            mov [.pe.dwSize], sizeof.PROCESSENTRY32W
            invoke Process32FirstW, rbx, addr .pe
            errorCheck
            .loop:
                mov [.item.iItem], esi
                mov [.item.mask], LVIF_TEXT or LVIF_PARAM or LVIF_GROUPID

                invoke swprintf, addr .buffer, wcsFmtHEX32, [.pe.th32ProcessID]
                mov edx, [.pe.th32ProcessID]
                lea rcx, [.buffer]
                mov [.item.lParam], rdx
                mov [.item.pszText], rcx
                mov [.item.iSubItem], 0
                invoke SendMessageW, [hPDList], LVM_INSERTITEMW, 0, addr .item
                errorCheck e, -1

                lea rcx, [.pe.szExeFile]
                and [.item.mask], not (LVIF_PARAM or LVIF_GROUPID)
                mov [.item.pszText], rcx
                inc [.item.iSubItem]
                invoke SendMessageW, [hPDList], LVM_SETITEMW, 0, addr .item
                errorCheck

                invoke OpenProcess, PROCESS_QUERY_INFORMATION, 0, [.pe.th32ProcessID]
                test rax, rax
                jz @f
                    mov rdi, rax
                    mov [.len], 256
                    invoke QueryFullProcessImageNameW, rax, 0, addr .buffer, addr .len
                    mov r12, rax
                    invoke CloseHandle, rdi
                    test r12, r12
                    jz @f
                        lea rcx, [.buffer]
                        mov [.item.pszText], rcx
                        inc [.item.iSubItem]
                        invoke SendMessageW, [hPDList], LVM_SETITEMW, 0, addr .item
                        errorCheck
                @@:

                invoke Process32NextW, rbx, addr .pe
                inc esi
                test rax, rax
                jnz .loop
                invoke GetLastError
                cmp rax, 18 ;ERROR_NO_MORE_FILES
                jne errorHandler
            invoke CloseHandle, rbx

            invoke SendMessageW, [hPDList], LVM_SETCOLUMNWIDTH, 0, LVSCW_AUTOSIZE
            errorCheck
            invoke SendMessageW, [hPDList], LVM_SETCOLUMNWIDTH, 1, LVSCW_AUTOSIZE
            errorCheck

            dec esi
            invoke SendMessageW, [hPDList], LVM_ENSUREVISIBLE, rsi, 1
            errorCheck
        endf
        ret
    endp

    proc ProcSetupFmt
        mov eax, [isRemoteWOW64]
        test eax, eax
        jnz .32
        ;64:
            mov [pszFmtFloat], szFmtFloat2
            mov [pszFmtSWord], szFmtQWord
            mov [pszFmtAddress], szFmtQWord
            ret
        .32:
            mov [pszFmtFloat], szFmtFloat
            mov [pszFmtSWord], szFmtDword
            mov [pszFmtAddress], szFmtDword
            ret
    endp

    include 'rs_tree/rs_tree.asm'

section '.data' data readable writeable
    list_idata1  equ
    list_idata2  equ
    list_idata4  equ
    list_idata8  equ
    list_idata16 equ

    list_udata1  equ
    list_udata2  equ
    list_udata4  equ
    list_udata8  equ
    list_udata16 equ

    macro add_data init, nalign, mmacro {
        list_#init#data#nalign equ list_#init#data#nalign mmacro
    }

    macro define_data init, nalign {
        match data, list_#init#data#nalign \{ _dd data \}
    }

    macro _dd data {
        forward
            data
    }

    macro ninclude filename {
        local .
        .:
            include filename
        if $ - . > 0
            display 'ninclude: "', filename, '" tried to define some data!', 13, 10
            err
        end if
    }

    ninclude 'rs_tree/rs_tree.inc'

    align 16, 0
    define_data i, 16

    align 8, 0
    pszFmtAddress           dq szFmtQWord
    pszFmtSWord             dq szFmtQWord
    pszFmtFloat             dq szFmtFloat2

    define_data i, 8

    align 4, 0
    ;List of classes:
    ;https://msdn.microsoft.com/en-us/library/windows/desktop/bb775507%28v=vs.85%29.aspx
    iccex INITCOMMONCONTROLSEX \
        sizeof.INITCOMMONCONTROLSEX,\    ;dwSize
        ICC_TAB_CLASSES or \
        ICC_TREEVIEW_CLASSES or \
        ICC_LISTVIEW_CLASSES

    irps name,\
        IDM_MAIN_FILE_NEW        \
        IDM_MAIN_FILE_OPEN       \
        IDM_MAIN_FILE_SAVE       \
        IDM_MAIN_FILE_SAVEAS     \
        IDM_MAIN_FILE_ATTACH     \
        IDM_MAIN_FILE_DETACH     \
        IDM_MAIN_EXIT            \
                                 \
        IDM_MAIN_CLS_NEW         \
        IDM_MAIN_CLS_OPEN        \
        IDM_MAIN_CLS_DELNOTUSED
    {
        common
            local id
            IDM_MAIN_MIN = 0
            id = 0
            Menu_Main_Handler_List:
        forward
            name = id
            id = id + 1
            dq Menu_Main_Handler_#name
        common
            IDM_MAIN_MAX = id
    }

    colorBackground         dd 0x00FFFFFF
    colorAddress            dd 0x000000C0
    colorOffset             dd 0x0000C000
    colorChar               dd 0x00C00000
    colorByte               dd 0x00000000
    colorComment            dd 0x00A0A0A0
    colorSelectedItem       dd 0x00F0F0F0
    colorValue              dd 0x004080C0

    marginAddress           dd 8
    marginOffset            dd 8
    marginChars             dd 8
    marginChar              dd 0
    marginBytes             dd 8
    marginByte              dd 4
    marginValue             dd 8
    marginMiddle            dd 4

    align 2, 0
    wstring wcsTerminal,    'Terminal'

    wstring wcsUnnamed,     'unnamed'

    wstring wcsPID,         'PID'
    wstring wcsName,        'Name'
    wstring wcsPath,        'Path'

    wstring wcsFmtHEX32,    '%08X'

    define_data i, 2

    align 1, 0
    string szUnnamed,       'unnamed'

    string szFmtQWord,      '%08X_%08X'
    string szFmtDword,      '%08X'
    string szFmtWord,       '%04X'
    string szFmtByte,       '%02X'
    string szFmtFloat,      '%-+13.5g'
    string szFmtFloat2,     '%-+13.5g %-+13.5g'
    string szFmtDouble,     '%-+19.11lg'

    define_data i, 1

;   string szItemFormat64,  '%016X %04X  %8s  %02X %02X %02X %02X  %02X %02X %02X %02X  // %f/%f'
    align 16, ?
    windowRect              RECT
    treeRect                RECT
    tabRect                 RECT
    itemRect                RECT
    itemDrawingRect         RECT
    treeDrawingRect         RECT

    define_data u, 16

    align 8, ?
    hProcessHeap            dq ?

    hRemoteProcess          dq ?

    hMainDialog             dq ?
    hTbControl              dq ?
    hTabControl             dq ?

    hFontTerminal           dq ?

    hBrushBackground        dq ?
    hBrushSelectedItem      dq ?

    hCurrTreeDialog         dq ?
    hCurrTreeControl        dq ?
    hTreeDialogs            dq 64 dup ?
    hTreeControls           dq 64 dup ?

    hTreeDCMem              dq ?
    hTreeBMMem              dq ?
    treeOldDrOrig           POINT

    hPDList                 dq ?

    treeItem                TVITEMEX
    listItem                LVITEM
    lvColumn                LVCOLUMN

    remoteBuffer            dq ?
    remoteRead              dq ?

    define_data u, 8

    align 4, ?
    isRemoteWOW64           dd ?

    define_data u, 4

    align 2, ?
    define_data u, 2

    align 1, ?
    define_data u, 1

section '.rsrc' resource data readable
    irps name,\
        RSRC_MAIN_DIALOG    \
        RSRC_TREE_DIALOG    \
        RSRC_PROC_DIALOG    \
                            \
        RSRC_MAIN_MENU      \
                            \
        RSRC_MAIN_ICON_DATA \
        RSRC_MAIN_ICON      \
        RSRC_APP_VERSION    \
                            \
        RSRC_TB_CONTROL     \
        RSRC_TAB_CONTROL    \
        RSRC_TREE_CONTROL   \
                            \
        RSRC_PD_LIST        \
        RSRC_PD_REFRESH     \
        RSRC_PD_OPEN        \
        RSRC_PD_CANCEL      \
        RSRC_PD_SEARCH
    {
        common
            local id
            id = 0
        forward
            name = id
            id = id + 1
    }


    directory RT_DIALOG,     dialogs,\
              RT_MENU,       menus,\
              RT_ICON,       icons,\
              RT_GROUP_ICON, group_icons,\
              RT_VERSION,    versions

    resource dialogs,\
        RSRC_MAIN_DIALOG,    LANG_ENGLISH or SUBLANG_DEFAULT, main_dialog,\
        RSRC_TREE_DIALOG,    LANG_ENGLISH or SUBLANG_DEFAULT, tree_dialog,\
        RSRC_PROC_DIALOG,    LANG_ENGLISH or SUBLANG_DEFAULT, proc_dialog

    resource menus,\
        RSRC_MAIN_MENU,      LANG_ENGLISH or SUBLANG_DEFAULT, main_menu

    resource icons,\
        RSRC_MAIN_ICON_DATA, LANG_NEUTRAL,                   icon_data

    resource group_icons,\
        RSRC_MAIN_ICON,      LANG_NEUTRAL,                   main_icon

    resource versions,\
        RSRC_APP_VERSION,    LANG_NEUTRAL,                   version

    dialog main_dialog,\
        'restruc',\                     ;title
        0,\                             ;x
        0,\                             ;y
        512,\                           ;cx
        128,\                           ;cy
        WS_CLIPCHILDREN or DS_CENTER or WS_OVERLAPPEDWINDOW,\ ;style
        WS_EX_CONTROLPARENT,\           ;exstyle
        RSRC_MAIN_MENU,\                ;menu
        'Terminal',\                    ;fontname
        6                               ;fontsize
                      ; class,            title, id,                x, y, cx,cy,  style, exstyle
            dialogitem 'ToolbarWindow32', '',    RSRC_TB_CONTROL,   0, 0, 0, 0, WS_VISIBLE or CCS_ADJUSTABLE
            dialogitem 'SysTabControl32', '',    RSRC_TAB_CONTROL,  0, 0, 0, 0, WS_VISIBLE or WS_TABSTOP or TCS_BUTTONS or TCS_FLATBUTTONS or TCS_MULTILINE
    enddialog

    dialog tree_dialog,\
        '',\                            ;title
        0,\                             ;x
        0,\                             ;y
        0,\                             ;cx
        0,\                             ;cy
        WS_CLIPCHILDREN or WS_VISIBLE or WS_CHILD or WS_TABSTOP,\ ;style
        0,\                             ;exstyle
        0,\                             ;menu
        'Terminal',\                    ;fontname
        6                               ;fontsize
                      ; class,            title, id,                x, y, cx,cy,  style, exstyle
            dialogitem 'SysTreeView32',   '',    RSRC_TREE_CONTROL, 0, 0, 0, 0, WS_VISIBLE or WS_TABSTOP or TVS_DISABLEDRAGDROP or TVS_FULLROWSELECT or TVS_HASBUTTONS or TVS_SHOWSELALWAYS
    enddialog

    dialog proc_dialog,\
        'Process List',\                ;title
        0,\                             ;x
        0,\                             ;y
        256,\                           ;cx
        256,\                           ;cy
        WS_CLIPCHILDREN or WS_OVERLAPPEDWINDOW,\           ;style
        WS_EX_DLGMODALFRAME,\           ;exstyle
        0,\                             ;menu
        'Terminal',\                    ;fontname
        6                               ;fontsize
                      ; class,            title,                      id,                  x, y, cx,cy,  style, exstyle
            dialogitem 'SysListView32',   '',                         RSRC_PD_LIST,        0, 0, 0, 0, WS_VISIBLE or WS_TABSTOP or LVS_REPORT or LVS_SINGLESEL or LVS_NOSORTHEADER
            dialogitem 'BUTTON',          '&Refresh',                 RSRC_PD_REFRESH,     0, 0, 0, 0, WS_VISIBLE or WS_TABSTOP
            dialogitem 'BUTTON',          '&Open',                    RSRC_PD_OPEN,        0, 0, 0, 0, WS_VISIBLE or WS_TABSTOP
            dialogitem 'BUTTON',          '&Cancel',                  RSRC_PD_CANCEL,      0, 0, 0, 0, WS_VISIBLE or WS_TABSTOP
            dialogitem 'STATIC',          'Search: (type to search)', RSRC_PD_SEARCH,      0, 0, 0, 0, WS_VISIBLE
    enddialog


    menu main_menu
        menuitem '&File', 0, MFR_POPUP
            menuitem '&New',                IDM_MAIN_FILE_NEW
            menuitem '&Open',               IDM_MAIN_FILE_OPEN
            menuitem '&Save',               IDM_MAIN_FILE_SAVE
            menuitem 'Save &As ..',         IDM_MAIN_FILE_SAVEAS
            menuseparator
            menuitem '&Attach ..',          IDM_MAIN_FILE_ATTACH
            menuitem '&Detach',             IDM_MAIN_FILE_DETACH
            menuseparator
            menuitem 'E&xit',               IDM_MAIN_EXIT,   MFR_END
        menuitem '&Class', 0, MFR_POPUP or MFR_END
            menuitem '&New',                IDM_MAIN_CLS_NEW
            menuitem '&Open',               IDM_MAIN_CLS_OPEN
            menuseparator
            menuitem '&Remove not used',    IDM_MAIN_CLS_DELNOTUSED, MFR_END


    icon main_icon, icon_data, 'icon.ico'

    versioninfo version,\
        VOS__WINDOWS32,\
        VFT_APP,\
        VFT2_UNKNOWN,\
        LANG_ENGLISH or SUBLANG_DEFAULT,\
        0,\
        'FileDescription',    'restruc - Yet another reverse engineering tool',\
        'LegalCopyright',     'RIscRIpt',\
        'FileVersion',        '0.1',\
        'ProductName',        'restruc',\
        'ProductVersion',     '0.1',\
        'OriginalFilename',   'restruc.exe'

section '.idata' import data readable writeable
    library kernel32,   'kernel32.dll',\
            user32,     'user32.dll',\
            gdi32,      'gdi32.dll',\
            comctl32,   'comctl32.dll',\
            msvcrt,     'msvcrt.dll'

    include 'api/kernel32.inc'
    include 'api/user32.inc'
    include 'api/gdi32.inc'
    include 'api/comctl32.inc'

    import msvcrt,\
        sprintf,        'sprintf',\
        swprintf,       'swprintf'

