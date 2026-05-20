set(CMAKE_SYSTEM_PROCESSOR hazard3)

# Runtime directory name looked up under lib/clang-runtimes/${PICO_CLANG_RUNTIME}
set(PICO_CLANG_RUNTIMES riscv32-unknown-elf)

# -mno-relax: prevents R_RISCV_RELAX markers.
# lld/eld RISC-V relaxation uses raw section offsets as P instead of placed VMAs,
# producing ~512 MB branch offsets. GNU ld does not have this issue.
set(PICO_COMMON_LANG_FLAGS "--target=riscv32-unknown-elf -march=rv32imac_zicsr_zifencei_zba_zbb_zbs_zbkb -mabi=ilp32 -mno-relax")

set(PICO_DISASM_OBJDUMP_ARGS "")

include(${CMAKE_CURRENT_LIST_DIR}/util/pico_arm_clang_common.cmake)

# For riscv32-unknown-elf, Clang's BareMetal driver automatically appends crt0.o
# at link time (unlike *-none-eabi ARM triples).
# pico-sdk supplies its own startup in crt0_riscv.S, so suppress the sysroot one.
foreach(TYPE IN ITEMS EXE SHARED MODULE)
    set(CMAKE_${TYPE}_LINKER_FLAGS_INIT "-nostartfiles")
endforeach()
