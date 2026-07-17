*&---------------------------------------------------------------------*
*& Report Z<program_name>
*&---------------------------------------------------------------------*
*& 基于 REUSE_ALV_GRID_DISPLAY_LVC 的 ALV 报表模板
*& 使用说明: 替换所有 <...> 占位符为实际内容
*&---------------------------------------------------------------------*
REPORT z<program_name> MESSAGE-ID <message_class>.

"----------------------------------------------------------------------
" 选择屏幕 - TABLES声明（用于SELECT-OPTIONS的FOR语法）
"----------------------------------------------------------------------
TABLES: <table_name>.

"----------------------------------------------------------------------
" 选择屏幕
"----------------------------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME.
  SELECT-OPTIONS: s_<field1> FOR <table_name>-<field1>.
  " 根据需要添加更多 SELECT-OPTIONS
SELECTION-SCREEN END OF BLOCK b1.

"----------------------------------------------------------------------
" 内表和工作区 - 定义输出结构
"----------------------------------------------------------------------
TYPES: BEGIN OF ty_data,
         " >>> 在此定义输出字段 <<<
         " field1 TYPE <datatype>,  " 字段描述
         " field2 TYPE <datatype>,  " 字段描述
         " 注: 货币字段需要对应 WAERK 字段
         "     数量字段需要对应 VRKME/MEINS 字段
       END OF ty_data.

DATA: gt_data TYPE TABLE OF ty_data,
      gs_data TYPE ty_data.

"----------------------------------------------------------------------
" 主逻辑
"----------------------------------------------------------------------
START-OF-SELECTION.

  " >>> 从数据库表中选择数据 <<<
  SELECT field1
         field2
         ...
    FROM <table_name>
    INTO CORRESPONDING FIELDS OF TABLE gt_data
    UP TO 100 ROWS
   WHERE field1 IN s_field1.

  IF sy-subrc <> 0.
    MESSAGE '没有符合条件的数据' TYPE 'S' DISPLAY LIKE 'E'.
    LEAVE LIST-PROCESSING.
  ENDIF.

  " 单位内外部转换（如有单位字段）
  LOOP AT gt_data INTO gs_data.
    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
      EXPORTING
        input          = gs_data-vrkme
        language       = sy-langu
      IMPORTING
        output         = gs_data-vrkme
      EXCEPTIONS
        unit_not_found = 1
        OTHERS         = 2.
    MODIFY gt_data FROM gs_data.
  ENDLOOP.

  " 显示ALV
  PERFORM frm_display_alv.

"----------------------------------------------------------------------
" 子程序: 显示ALV
"----------------------------------------------------------------------
FORM frm_display_alv.

  DATA:
    lt_fieldcat TYPE lvc_t_fcat,
    ls_layout   TYPE lvc_s_layo.

  ls_layout-zebra      = abap_on.
  ls_layout-cwidth_opt = abap_on.

  " >>> 构建字段目录 - 在此添加所有输出字段 <<<
  " 参数: fieldname text ref_table ref_field cfieldname qfieldname
  " 普通字段: 后4个参数传 ''
  " 金额字段: cfieldname=货币字段名(如'WAERK')
  " 数量字段: qfieldname=单位字段名(如'VRKME')
  PERFORM f_build_fieldcat
    USING: 'FIELD1' '字段描述1' ''   ''   ''   '' CHANGING lt_fieldcat,
           'FIELD2' '字段描述2' ''   ''   ''   '' CHANGING lt_fieldcat.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
      i_callback_program       = sy-repid
      i_callback_pf_status_set = 'F_SET_PF_STATUS'
      i_callback_user_command  = 'F_USER_COMMAND'
      is_layout_lvc            = ls_layout
      it_fieldcat_lvc          = lt_fieldcat
    TABLES
      t_outtab                 = gt_data
    EXCEPTIONS
      program_error            = 1
      OTHERS                   = 2.

  IF sy-subrc <> 0.
    MESSAGE 'ALV显示错误' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.

"----------------------------------------------------------------------
" 子程序: 设置PF STATUS
"----------------------------------------------------------------------
FORM f_set_pf_status USING rt_extab TYPE slis_t_extab ##CALLED ##NEEDED.
  SET PF-STATUS 'STANDARD_FULLSCREEN'.
ENDFORM.

"----------------------------------------------------------------------
" 子程序: 用户命令处理
"----------------------------------------------------------------------
FORM f_user_command USING u_ucomm   LIKE sy-ucomm
                          u_s_selfield TYPE slis_selfield ##CALLED.
  " 在此添加自定义用户命令处理
  CASE u_ucomm.
    " WHEN '&IC1'.  " 双击事件
    "   ...
    WHEN OTHERS.
  ENDCASE.
ENDFORM.

"----------------------------------------------------------------------
" 子程序: 构建字段目录
" 参数说明:
"   u_v_fieldname - 字段名
"   u_v_text      - 显示文本
"   u_v_reftable  - 引用表名（如 'VBAP'），用于域转换
"   u_v_reffield  - 引用字段名（如 'NETWR'）
"   u_v_cfield    - 货币字段名（如 'WAERK'），金额字段使用
"   u_v_qfield    - 数量单位字段名（如 'VRKME'），数量字段使用
"----------------------------------------------------------------------
FORM f_build_fieldcat USING    u_v_fieldname TYPE char50
                                u_v_text      TYPE char50
                                u_v_reftable  TYPE char50
                                u_v_reffield  TYPE char50
                                u_v_cfield    TYPE char50
                                u_v_qfield    TYPE char50
                       CHANGING c_t_fieldcat  TYPE lvc_t_fcat.

  DATA: ls_fieldcat TYPE lvc_s_fcat.

  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname    = u_v_fieldname.
  ls_fieldcat-ref_table    = u_v_reftable.
  ls_fieldcat-ref_field    = u_v_reffield.
  ls_fieldcat-cfieldname   = u_v_cfield.
  ls_fieldcat-qfieldname   = u_v_qfield.
  ls_fieldcat-scrtext_l    = u_v_text.
  ls_fieldcat-scrtext_m    = u_v_text.
  ls_fieldcat-scrtext_s    = u_v_text.

  APPEND ls_fieldcat TO c_t_fieldcat.

ENDFORM.
