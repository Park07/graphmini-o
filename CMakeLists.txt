cmake_minimum_required(VERSION 3.20)
project(GraphMini)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# macOS specific settings
if(APPLE)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++")
    # Use Homebrew's LLVM OpenMP
    set(OpenMP_ROOT /opt/homebrew/opt/libomp)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Xpreprocessor -fopenmp")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -lomp")
endif()

# Find packages
find_package(OpenMP REQUIRED)
find_package(TBB REQUIRED)
find_package(MPI REQUIRED)

# Add fmt library (install via brew install fmt or use FetchContent)
find_package(fmt QUIET)
if(NOT fmt_FOUND)
    include(FetchContent)
    FetchContent_Declare(
        fmt
        GIT_REPOSITORY https://github.com/fmtlib/fmt.git
        GIT_TAG 9.1.0
    )
    FetchContent_MakeAvailable(fmt)
endif()

# Add cxxopts for command line parsing
find_package(cxxopts QUIET)
if(NOT cxxopts_FOUND)
    include(FetchContent)
    FetchContent_Declare(
        cxxopts
        GIT_REPOSITORY https://github.com/jarro2783/cxxopts.git
        GIT_TAG v3.1.1
    )
    FetchContent_MakeAvailable(cxxopts)
endif()

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

# Install dependencies for macOS
if(APPLE)
    # Add Homebrew paths
    include_directories(/opt/homebrew/include)
    link_directories(/opt/homebrew/lib)
endif()