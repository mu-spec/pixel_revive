cmake_minimum_required(VERSION 3.18.1)

project(pixel_processor VERSION 1.0.0 LANGUAGES CXX)

# Add our high-speed C++ pixel processor source file
add_library(pixel_processor SHARED
  ../../src/pixel_processor.cpp
)

find_library(log-lib log)

target_link_libraries(pixel_processor
  ${log-lib}
)