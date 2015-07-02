;pointers in structs must be aligned by 8
;credits: http://blog.csdn.net/haven200/article/details/12529353

struct TCITEM
    mask            dd ?
    dwState         dd ?
    dwStateMask     dd ?
                    dd ? ;align pointer
    pszText         dq ?
    cchTextMax      dd ?
    iImage          dd ?
    lParam          dq ?
ends

struct TVITEM
    mask            dd ?
                    dd ? ;align pointer
    hItem           dq ?
    state           dd ?
    stateMask       dd ?
    pszText         dq ?
    cchTextMax      dd ?
    iImage          dd ?
    iSelectedImage  dd ?
    cChildren       dd ?
    lParam          dq ?
ends

struct TVITEMEX
    mask            dd ?
                    dd ? ;align pointer
    hItem           dq ?
    state           dd ?
    stateMask       dd ?
    pszText         dq ?
    cchTextMax      dd ?
    iImage          dd ?
    iSelectedImage  dd ?
    cChildren       dd ?
    lParam          dq ?
    iIntegral       dd ?
    uStateEx        dd ?
    hwnd            dq ?
    iExpandedImage  dd ?
    iReserved       dd ?
ends

struct TVINSERTSTRUCT
    hParent         dq ?
    hInsertAfter    dq ?
    union
        itemex      TVITEMEX
        item        TVITEM
    ends
ends

struct NMCUSTOMDRAW
    hdr             NMHDR
                    dd ? ;align struct
    dwDrawStage     dd ?
                    dd ? ;align pointer
    hdc             dq ?
    rc              RECT
    dwItemSpec      dq ?
    uItemState      dd ?
                    dd ? ;align pointer
    lItemlParam     dq ?
ends

struct NMTVCUSTOMDRAW
    nmcd            NMCUSTOMDRAW
    clrText         dd ?
    clrTextBk       dd ?
    iLevel          dd ?
ends

struct NMTREEVIEW
    hdr             NMHDR
                    dd ? ;align struct
    action          dd ?
                    dd ? ;align struct
    itemOld         TVITEM
    itemNew         TVITEM
    ptDrag          POINT
ends

struct LVCOLUMN
    mask            dd ?
    fmt             dd ?
    cx              dd ?
                    dd ? ;align pointer
    pszText         dq ?
    cchTextMax      dd ?
    iSubItem        dd ?
    iImage          dd ?
    iOrder          dd ?
    cxMin           dd ?
    cxDefault       dd ?
    cxIdeal         dd ?
                    dd ? ;align struct
ends

struct LVITEM
    mask            dd ?
    iItem           dd ?
    iSubItem        dd ?
    state           dd ?
    stateMask       dd ?
                    dd ? ;align pointer
    pszText         dq ?
    cchTextMax      dd ?
    iImage          dd ?
    lParam          dq ?
    iIndent         dd ?
    iGroupId        dd ?
    cColumns        dd ?
                    dd ?
    puColumns       dq ?
    piColFmt        dq ?
    iGroup          dd ?
                    dd ? ;align struct
ends

struct NMITEMACTIVATE
    hdr             NMHDR
                    dd ? ;align struct
    iItem           dd ?
    iSubItem        dd ?
    uNewState       dd ?
    uOldState       dd ?
    uChanged        dd ?
    ptAction        POINT
                    dd ? ;align pointer
    lParam          dq ?
    uKeyFlags       dd ?
                    dd ? ;align struct
ends

TCS_FLATBUTTONS     = 0x0008

TVI_ROOT            = -0x10000
TVI_FIRST           = -0x0FFFF
TVI_LAST            = -0x0FFFE
TVI_SORT            = -0x0FFFD

LVIF_GROUPID        = 0x00000100

I_GROUPIDCALLBACK   = -1
I_GROUPIDNONE       = -2

TVM_SETEXTENDEDSTYLE= TV_FIRST + 44

TVS_EX_NOSINGLECOLLAPSE    = 0x0001
TVS_EX_MULTISELECT         = 0x0002
TVS_EX_DOUBLEBUFFER        = 0x0004
TVS_EX_NOINDENTSTATE       = 0x0008
TVS_EX_RICHTOOLTIP         = 0x0010
TVS_EX_AUTOHSCROLL         = 0x0020
TVS_EX_FADEINOUTEXPANDOS   = 0x0040
TVS_EX_PARTIALCHECKBOXES   = 0x0080
TVS_EX_EXCLUSIONCHECKBOXES = 0x0100
TVS_EX_DIMMEDCHECKBOXES    = 0x0200
TVS_EX_DRAWIMAGEASYNC      = 0x0400

