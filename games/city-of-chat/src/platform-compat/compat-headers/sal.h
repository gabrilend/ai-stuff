#ifndef SAL_H_COMPAT
#define SAL_H_COMPAT

// Compatibility header for Microsoft Source Annotation Language (sal.h) on Linux
// Provides empty definitions for SAL annotations used by Windows code

// Most common SAL annotations - define as empty macros
#define _In_
#define _Out_
#define _Inout_
#define _In_opt_
#define _Out_opt_
#define _Inout_opt_
#define _In_z_
#define _Out_z_
#define _Inout_z_
#define _In_reads_(size)
#define _In_reads_opt_(size)
#define _In_reads_bytes_(size)
#define _In_reads_bytes_opt_(size)
#define _In_reads_z_(size)
#define _In_reads_or_z_(size)
#define _Out_writes_(size)
#define _Out_writes_opt_(size)
#define _Out_writes_bytes_(size)
#define _Out_writes_bytes_opt_(size)
#define _Out_writes_z_(size)
#define _Out_writes_to_(size, count)
#define _Out_writes_to_opt_(size, count)
#define _Out_writes_all_(size)
#define _Out_writes_all_opt_(size)
#define _Inout_updates_(size)
#define _Inout_updates_opt_(size)
#define _Inout_updates_z_(size)
#define _Inout_updates_to_(size, count)
#define _Field_size_(size)
#define _Field_size_opt_(size)
#define _Field_size_bytes_(size)
#define _Field_size_bytes_opt_(size)
#define _Field_range_(min, max)
#define _Pre_
#define _Post_
#define _Pre_valid_
#define _Post_valid_
#define _Pre_invalid_
#define _Post_invalid_
#define _Pre_unknown_
#define _Post_unknown_
#define _Pre_null_
#define _Post_null_
#define _Pre_notnull_
#define _Post_notnull_
#define _Pre_maybenull_
#define _Post_maybenull_
#define _Pre_z_
#define _Post_z_
#define _Pre_readable_size_(size)
#define _Pre_writable_size_(size)
#define _Pre_readable_byte_size_(size)
#define _Pre_writable_byte_size_(size)
#define _Post_readable_size_(size)
#define _Post_writable_size_(size)
#define _Post_readable_byte_size_(size)
#define _Post_writable_byte_size_(size)
#define _Ret_
#define _Ret_opt_
#define _Ret_null_
#define _Ret_notnull_
#define _Ret_maybenull_
#define _Ret_z_
#define _Ret_writes_(size)
#define _Ret_writes_opt_(size)
#define _Ret_writes_bytes_(size)
#define _Ret_writes_bytes_opt_(size)
#define _Ret_writes_z_(size)
#define _Ret_writes_to_(size, count)
#define _Ret_writes_maybenull_(size)
#define _Ret_writes_maybenull_z_(size)
#define _Check_return_
#define _Must_inspect_result_
#define _Printf_format_string_
#define _Scanf_format_string_
#define _Scanf_s_format_string_
#define _Format_string_impl_(kind, where)
#define _Null_terminated_
#define _NullNull_terminated_
#define _Reserved_
#define _Callback_
#define _Points_to_data_
#define _Literal_
#define _Notliteral_
#define _Const_
#define _Analysis_assume_(expr)
#define _Analysis_assume_nullterminated_(x)
#define _At_(target, cond)
#define _When_(expr, cond)
#define _Success_(expr)
#define _On_failure_(expr)
#define _Always_(expr)
#define _Use_decl_annotations_
#define _Acquires_lock_(lock)
#define _Releases_lock_(lock)
#define _Acquires_shared_lock_(lock)  
#define _Releases_shared_lock_(lock)
#define _Acquires_exclusive_lock_(lock)
#define _Releases_exclusive_lock_(lock)
#define _Has_lock_kind_(kind)
#define _Has_lock_level_(level)
#define _Lock_level_order_(before, after)
#define _Post_same_lock_(expr1, expr2)
#define _Benign_race_begin_
#define _Benign_race_end_
#define _No_competing_thread_
#define _No_competing_thread_begin_
#define _No_competing_thread_end_
#define _Requires_lock_held_(lock)
#define _Requires_lock_not_held_(lock)
#define _Requires_shared_lock_held_(lock)
#define _Requires_exclusive_lock_held_(lock)
#define _Requires_no_locks_held_
#define _Guarded_by_(lock)
#define _Interlocked_
#define _Interlocked_operand_
#define _IRQL_requires_(irql)
#define _IRQL_requires_max_(irql)
#define _IRQL_requires_min_(irql)
#define _IRQL_raises_(irql)
#define _IRQL_lowers_(irql)
#define _IRQL_saves_
#define _IRQL_restores_
#define _IRQL_saves_global_(kind, param)
#define _IRQL_restores_global_(kind, param)
#define _IRQL_always_function_min_(irql)
#define _IRQL_always_function_max_(irql)
#define _IRQL_requires_same_
#define _IRQL_uses_cancel_
#define _Kernel_float_saved_
#define _Kernel_float_restored_
#define _Kernel_float_used_
#define _Kernel_acquires_resource_(kind, param)
#define _Kernel_releases_resource_(kind, param)
#define _Kernel_requires_resource_held_(kind, param)
#define _Kernel_requires_resource_not_held_(kind, param)

#endif // SAL_H_COMPAT