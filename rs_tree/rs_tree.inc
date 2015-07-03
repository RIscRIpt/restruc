macro rs_tree_idata8 {
    include 'rs_tree/rs_tree_keytable.inc'
}

macro rs_tree_udata1 {
    szRSItemBuffer          db 128 dup ?
}

add_data i, 8, rs_tree_idata8

add_data u, 1, rs_tree_udata1

