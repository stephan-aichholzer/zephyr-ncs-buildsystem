cmake_minimum_required(VERSION 3.20.5)
# Host-compiled unit test: no kernel, no board, output is a plain x86 ELF.
find_package(Zephyr COMPONENTS unittest REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(test_greet)

set(MODULE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../src/common/greet)
target_include_directories(testbinary PRIVATE ${MODULE_DIR})
target_sources(testbinary PRIVATE
    ${MODULE_DIR}/greet.c
    src/test_greet.c
)

# Rename the executable on disk. TEST_TARGET is passed by the top-level
# tests/CMakeLists.txt; fall back to a sensible default for direct cmake.
if(NOT DEFINED TEST_TARGET)
    set(TEST_TARGET ztest_common_greet)
endif()
set_target_properties(testbinary PROPERTIES OUTPUT_NAME ${TEST_TARGET})
