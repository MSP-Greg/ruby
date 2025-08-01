/* -*-c-*- */
/**********************************************************************

  vm_exec.c -

  $Author$

  Copyright (C) 2004-2007 Koichi Sasada

**********************************************************************/

#include <math.h>

#if USE_YJIT || USE_ZJIT
// The number of instructions executed on vm_exec_core. --yjit-stats and --zjit-stats use this.
uint64_t rb_vm_insns_count = 0;
#endif

#if VM_COLLECT_USAGE_DETAILS
static void vm_analysis_insn(int insn);
#endif

#if VMDEBUG > 0
#define DECL_SC_REG(type, r, reg) register type reg_##r

#elif defined(__GNUC__) && defined(__x86_64__)
#define DECL_SC_REG(type, r, reg) register type reg_##r __asm__("r" reg)

#elif defined(__GNUC__) && defined(__i386__)
#define DECL_SC_REG(type, r, reg) register type reg_##r __asm__("e" reg)

#elif defined(__GNUC__) && (defined(__powerpc64__) || defined(__POWERPC__))
#define DECL_SC_REG(type, r, reg) register type reg_##r __asm__("r" reg)

#elif defined(__GNUC__) && defined(__aarch64__)
#define DECL_SC_REG(type, r, reg) register type reg_##r __asm__("x" reg)

#else
#define DECL_SC_REG(type, r, reg) register type reg_##r
#endif
/* #define DECL_SC_REG(r, reg) VALUE reg_##r */

#if !OPT_CALL_THREADED_CODE
static VALUE
vm_exec_core(rb_execution_context_t *ec)
{
#if defined(__GNUC__) && defined(__i386__)
    DECL_SC_REG(const VALUE *, pc, "di");
    DECL_SC_REG(rb_control_frame_t *, cfp, "si");
#define USE_MACHINE_REGS 1

#elif defined(__GNUC__) && defined(__x86_64__)
    DECL_SC_REG(const VALUE *, pc, "14");
    DECL_SC_REG(rb_control_frame_t *, cfp, "15");
#define USE_MACHINE_REGS 1

#elif defined(__GNUC__) && (defined(__powerpc64__) || defined(__POWERPC__))
    DECL_SC_REG(const VALUE *, pc, "14");
    DECL_SC_REG(rb_control_frame_t *, cfp, "15");
#define USE_MACHINE_REGS 1

#elif defined(__GNUC__) && defined(__aarch64__)
    DECL_SC_REG(const VALUE *, pc, "19");
    DECL_SC_REG(rb_control_frame_t *, cfp, "20");
#define USE_MACHINE_REGS 1

#else
    register rb_control_frame_t *reg_cfp;
    const VALUE *reg_pc;
#define USE_MACHINE_REGS 0

#endif

#if USE_MACHINE_REGS

#undef  RESTORE_REGS
#define RESTORE_REGS() \
{ \
  VM_REG_CFP = ec->cfp; \
  reg_pc  = reg_cfp->pc; \
}

#undef  VM_REG_PC
#define VM_REG_PC reg_pc
#undef  GET_PC
#define GET_PC() (reg_pc)
#undef  SET_PC
#define SET_PC(x) (reg_cfp->pc = VM_REG_PC = (x))
#endif

#if OPT_TOKEN_THREADED_CODE || OPT_DIRECT_THREADED_CODE
#include "vmtc.inc"
    if (UNLIKELY(ec == 0)) {
        return (VALUE)insns_address_table;
    }
#endif
    reg_cfp = ec->cfp;
    reg_pc = reg_cfp->pc;

  first:
    INSN_DISPATCH();
/*****************/
 #include "vm.inc"
/*****************/
    END_INSNS_DISPATCH();

    /* unreachable */
    rb_bug("vm_eval: unreachable");
    goto first;
}

const void **
rb_vm_get_insns_address_table(void)
{
    return (const void **)vm_exec_core(0);
}

#else /* OPT_CALL_THREADED_CODE */

#include "vm.inc"
#include "vmtc.inc"

const void **
rb_vm_get_insns_address_table(void)
{
    return (const void **)insns_address_table;
}

static VALUE
vm_exec_core(rb_execution_context_t *ec)
{
    register rb_control_frame_t *reg_cfp = ec->cfp;
    rb_thread_t *th;

    while (1) {
        reg_cfp = ((rb_insn_func_t) (*GET_PC()))(ec, reg_cfp);

        if (UNLIKELY(reg_cfp == 0)) {
            break;
        }
    }

    if (!UNDEF_P((th = rb_ec_thread_ptr(ec))->retval)) {
        VALUE ret = th->retval;
        th->retval = Qundef;
        return ret;
    }
    else {
        VALUE err = ec->errinfo;
        ec->errinfo = Qnil;
        return err;
    }
}
#endif
