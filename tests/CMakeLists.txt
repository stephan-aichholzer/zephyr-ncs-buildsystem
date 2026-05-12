cmake_minimum_required(VERSION 3.20.5)
project(zephyr_unit_tests NONE)

# Aggregator: walks tests/**/CMakeLists.txt and wraps each leaf test as its
# own self-contained Zephyr unittest build via ExternalProject_Add. Result:
# one executable per test directory, named ztest_<path>, with full isolation.

include(ExternalProject)

file(GLOB_RECURSE TEST_LISTS
     RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
     CONFIGURE_DEPENDS
     CMakeLists.txt)
list(REMOVE_ITEM TEST_LISTS CMakeLists.txt)  # exclude this file

foreach(lst ${TEST_LISTS})
    get_filename_component(test_dir ${lst} DIRECTORY)
    string(REPLACE "/" "_" suffix ${test_dir})
    set(test_target ztest_${suffix})

    ExternalProject_Add(${test_target}
        SOURCE_DIR      ${CMAKE_CURRENT_SOURCE_DIR}/${test_dir}
        BINARY_DIR      ${CMAKE_CURRENT_BINARY_DIR}/${test_target}
        BUILD_ALWAYS    1
        INSTALL_COMMAND ""
        CMAKE_GENERATOR Ninja
        CMAKE_ARGS      -DBOARD=unit_testing
                        -DZEPHYR_BASE=$ENV{ZEPHYR_BASE}
                        -DTEST_TARGET=${test_target}
    )
endforeach()
