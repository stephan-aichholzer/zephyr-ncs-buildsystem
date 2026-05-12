cmake_minimum_required(VERSION 3.20.5)
# COMPONENTS unittest: host-compiled unit test, no Zephyr kernel, no board.
# Target name is `testbinary`, output runs as a plain Linux executable.
find_package(Zephyr COMPONENTS unittest REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(test_greet)

set(MODULE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../src/common/greet)
target_include_directories(testbinary PRIVATE ${MODULE_DIR})
target_sources(testbinary PRIVATE
    ${MODULE_DIR}/greet.c
    src/test_greet.c
)
