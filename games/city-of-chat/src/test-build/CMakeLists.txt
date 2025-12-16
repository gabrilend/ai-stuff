cmake_minimum_required(VERSION 3.16)
project(CoHTest VERSION 1.0.0 LANGUAGES C CXX)

# Set C and C++ standards
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# Find packages
find_package(ZLIB REQUIRED)
find_package(OpenSSL REQUIRED)

# Include directories (compatibility headers first to override system headers)
include_directories(BEFORE ${CMAKE_SOURCE_DIR}/../platform-compat/compat-headers)
include_directories(BEFORE ${CMAKE_SOURCE_DIR}/../platform-compat)
include_directories(${CMAKE_SOURCE_DIR}/../coh-source/libs/UtilitiesLib/include)
include_directories(${CMAKE_SOURCE_DIR}/../coh-source/Common)

# Set up our custom library paths
set(LIBS_DIR ${CMAKE_SOURCE_DIR}/../../libs)
set(ZLIB_DIR ${LIBS_DIR}/zlib)
set(OPENSSL_DIR ${LIBS_DIR}/openssl)

# Custom library paths
link_directories(${ZLIB_DIR}/lib)
link_directories(${OPENSSL_DIR}/lib)
include_directories(${ZLIB_DIR}/include)
include_directories(${OPENSSL_DIR}/include)

# Collect non-Windows specific source files
file(GLOB_RECURSE UTILITIES_SOURCES 
    "../coh-source/libs/UtilitiesLib/src/version/*.c"
    "../coh-source/libs/UtilitiesLib/src/utils/PigDir.c"
    "../coh-source/libs/UtilitiesLib/src/utils/osdependent.c" 
    "../coh-source/libs/UtilitiesLib/src/utils/CommandFileParser.c"
    "../coh-source/libs/UtilitiesLib/src/utils/dds.c"
    "../coh-source/libs/UtilitiesLib/src/utils/fileWatch.c"
    "../coh-source/libs/UtilitiesLib/src/utils/structDefines.c"
)

# Create test utility library
add_library(UtilitiesTest STATIC ${UTILITIES_SOURCES})

# Set compiler flags
target_compile_definitions(UtilitiesTest PRIVATE
    -DLINUX=1
    -D_GNU_SOURCE=1
    -DHAVE_CONFIG_H=1
    -Dio_h_included=1
)

target_compile_options(UtilitiesTest PRIVATE
    -Wall
    -Wextra
    -Wno-unused-parameter
    -Wno-unused-function
    -Wno-missing-field-initializers
    -Wno-unknown-pragmas
    -Wno-pointer-sign
    -Wno-sign-compare
    -Wno-multichar
    -Wno-missing-braces
    -Wno-incompatible-pointer-types
    -include ${CMAKE_SOURCE_DIR}/../platform-compat/platform_compat.h
)

# Link libraries
target_link_libraries(UtilitiesTest 
    PRIVATE 
    z
    ssl
    crypto
    pthread
    dl
    m
)

# Create a test executable
add_executable(coh_test test_main.c)
target_link_libraries(coh_test UtilitiesTest)

# Install targets
install(TARGETS UtilitiesTest coh_test
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)