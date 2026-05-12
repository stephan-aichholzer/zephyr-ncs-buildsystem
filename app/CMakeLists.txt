cmake_minimum_required(VERSION 3.20.5)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(zephyr_hello)

set(COMMON_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../src/common)
target_include_directories(app PRIVATE ${COMMON_DIR}/greet)
target_sources(app PRIVATE
    src/main.c
    ${COMMON_DIR}/greet/greet.c
)
