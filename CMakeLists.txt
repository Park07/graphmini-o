cmake_minimum_required(VERSION 3.20)
project(GraphMini)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# macOS specific settings
if(APPLE)
    # Use system clang with libc++
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++")

    # OpenMP support for macOS
    if(EXISTS "/usr/local/opt/libomp")
        # Intel Mac path
        set(OpenMP_ROOT /usr/local/opt/libomp)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Xpreprocessor -fopenmp")
        set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -L/usr/local/opt/libomp/lib -lomp")
        include_directories(/usr/local/opt/libomp/include)
    elseif(EXISTS "/opt/homebrew/opt/libomp")
        # Apple Silicon path
        set(OpenMP_ROOT /opt/homebrew/opt/libomp)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Xpreprocessor -fopenmp")
        set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -L/opt/homebrew/opt/libomp/lib -lomp")
        include_directories(/opt/homebrew/opt/libomp/include)
    endif()
endif()

# Find packages
find_package(TBB REQUIRED)

# Try to find OpenMP, but don't fail if not found
find_package(OpenMP QUIET)
if(OpenMP_CXX_FOUND)
    message(STATUS "OpenMP found")
else()
    message(WARNING "OpenMP not found, using manual configuration")
endif()

# Add fmt library via FetchContent (safer than relying on system)
include(FetchContent)
FetchContent_Declare(
    fmt
    GIT_REPOSITORY https://github.com/fmtlib/fmt.git
    GIT_TAG 9.1.0
)
FetchContent_MakeAvailable(fmt)

# Add cxxopts for command line parsing
FetchContent_Declare(
    cxxopts
    GIT_REPOSITORY https://github.com/jarro2783/cxxopts.git
    GIT_TAG v3.1.1
)
FetchContent_MakeAvailable(cxxopts)

# Include directories
include_directories(include)
include_directories(dependency)

# Configure header
configure_file(include/configure.h.in include/configure.h @ONLY)
include_directories(${CMAKE_BINARY_DIR}/include)

# Set output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

set(PROJECT_PLAN_DIR ${CMAKE_BINARY_DIR}/plan)
set(PROJECT_LOG_DIR ${CMAKE_BINARY_DIR}/log)
set(PROJECT_PROFILE_DIR ${CMAKE_BINARY_DIR}/profile)

# Create directories
file(MAKE_DIRECTORY ${PROJECT_PLAN_DIR})
file(MAKE_DIRECTORY ${PROJECT_LOG_DIR})
file(MAKE_DIRECTORY ${PROJECT_PROFILE_DIR})

# Add subdirectories
add_subdirectory(dependency/GraphPi)
add_subdirectory(src)

# Platform-specific linking
if(APPLE)
    if(EXISTS "/usr/local/lib")
        link_directories(/usr/local/lib)
    endif()
    if(EXISTS "/opt/homebrew/lib")
        link_directories(/opt/homebrew/lib)
    endif()
endif()