---
name: sap-abap-alv-template
description: 'Generate ABAP ALV reports using REUSE_ALV_GRID_DISPLAY_LVC. Use when user asks to create an ALV report, ALV program, display table data with ALV, or generate ABAP list viewer output.'
---

# SAP ABAP ALV 报表模板

## 何时使用

- 用户要求创建 ABAP ALV 报表
- 需要从 ABAP 表中取数并以 ALV 网格显示
- 需要生成带选择屏幕的报表程序
- 需要使用 `REUSE_ALV_GRID_DISPLAY_LVC` 函数模块

## 模板代码

```abap
*&---------------------------------------------------------------------*
*& Report Z<program_name>
*&---------------------------------------------------------------------*
*&
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
" 内表和工作区
"----------------------------------------------------------------------
TYPES: BEGIN OF ty_data,
         " 在此定义输出字段
         field1 TYPE <datatype>,  " 字段描述
         field2 TYPE <datatype>,  " 字段描述
         " 注: 货币字段需要对应 WAERK 字段
         "     数量字段需要对应 VRKME/MEINS 字段
       END OF ty_data.

DATA: gt_data TYPE TABLE OF ty_data,
      gs_data TYPE ty_data.

"----------------------------------------------------------------------
" 主逻辑
"----------------------------------------------------------------------
START-OF-SELECTION.

  " 从数据库表中选择数据
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
        input          = gs_data-<unit_field>
        language       = sy-langu
      IMPORTING
        output         = gs_data-<unit_field>
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

  " 普通字段（ref_table / ref_field / cfieldname / qfieldname 均传空）
  PERFORM f_build_fieldcat
    USING: 'FIELD1' '字段描述1' ''   ''   ''   '' CHANGING lt_fieldcat,
           'FIELD2' '字段描述2' ''   ''   ''   '' CHANGING lt_fieldcat.

  " 金额字段 - 指定货币引用字段（cfieldname）
  " PERFORM f_build_fieldcat
  "   USING: 'NETWR' '描述' 'REF_TAB' 'REF_FIELD' 'WAERK' '' CHANGING lt_fieldcat.

  " 数量字段 - 指定单位引用字段（qfieldname）
  " PERFORM f_build_fieldcat
  "   USING: 'KWMENG' '描述' 'REF_TAB' 'REF_FIELD' '' 'VRKME' CHANGING lt_fieldcat.

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
  CASE u_ucomm.
    " WHEN '&IC1'.  " 双击事件处理
    WHEN OTHERS.
  ENDCASE.
ENDFORM.

"----------------------------------------------------------------------
" 子程序: 构建字段目录
"----------------------------------------------------------------------
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
```

## 使用步骤

1. **确定主表** - 确认用户要显示哪张 SAP 表的数据
2. **查询表结构** - 使用 `get_abap_object_lines` 读取表定义，获取字段名和数据类型
3. **确定输出字段** - 与用户确认需要显示的字段列表
4. **生成程序** - 使用 `create_object_programmatically` 创建程序（PROG/P）
5. **填入模板** - 将模板代码适配到具体场景：
   - 替换 `<program_name>`、`<table_name>`、`<field>` 等占位符
   - 定义 `TYPES` 结构与输出字段匹配
   - 编写 `SELECT` 语句从数据库取数
   - 在 `f_build_fieldcat` 调用中添加每个输出字段
6. **添加选择条件** - 根据需要添加 `SELECT-OPTIONS` 供用户筛选
7. **字段目录参数配置** - 根据字段类型设置参数：
   - **普通字段**：`ref_table`、`ref_field`、`cfieldname`、`qfieldname` 传空字符串 `''`
   - **金额字段**：设置 `ref_table`=表名、`ref_field`=字段名、`cfieldname`=货币字段名（如 `'WAERK'`）
   - **数量字段**：设置 `ref_table`=表名、`ref_field`=字段名、`qfieldname`=单位字段名（如 `'VRKME'`）
   - **单位字段**：设置 `ref_table`=表名、`ref_field`=字段名（触发域转换输出）

## 字段目录参数速查

| 字段类型 | ref_table | ref_field | cfieldname | qfieldname |
|----------|-----------|-----------|------------|------------|
| 普通文本/编码 | `''` | `''` | `''` | `''` |
| 金额（如 NETWR） | `'VBAP'` | `'NETWR'` | `'WAERK'` | `''` |
| 数量（如 KWMENG） | `'VBAP'` | `'KWMENG'` | `''` | `'VRKME'` |
| 单位（如 VRKME） | `'VBAP'` | `'VRKME'` | `''` | `''` |
| 货币（如 WAERK） | `'VBAP'` | `'WAERK'` | `''` | `''` |

## 单位内外部转换

数据选取后，对单位字段调用 `CONVERSION_EXIT_CUNIT_OUTPUT` 进行内外部转换：

```abap
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
```

## 参考模板程序

程序 `Z184606_ALV_VBAP`（包 Z184606_TEST_USE）是一个完整示例，展示了从 VBAP 表显示销售凭证数据的 ALV 报表。

## 注意事项

- **货币字段**（`NETWR` 等）：必须在 `cfieldname` 中指定对应的货币代码字段（如 `WAERK`），ALV 自动根据货币代码格式化金额（千分位、小数位）
- **数量字段**（`KWMENG` 等）：必须在 `qfieldname` 中指定对应的单位字段（如 `VRKME`），ALV 自动根据单位格式化数量
- **单位显示**：`CONVERSION_EXIT_CUNIT_OUTPUT` 将内部单位（如 `ST`）转为外部显示（如 `PC`）
- `TABLES` 声明用于选择屏幕的 `FOR` 语法
- 使用 `UP TO 100 ROWS` 限制数据量避免性能问题
