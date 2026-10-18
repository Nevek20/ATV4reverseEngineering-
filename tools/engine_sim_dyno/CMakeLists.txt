cmake_minimum_required(VERSION 3.10)
project(dyno)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_BUILD_TYPE Release)
add_compile_options(-include ${CMAKE_SOURCE_DIR}/compat.h -w)
set(ES ${CMAKE_SOURCE_DIR}/es)
include(FetchContent)
FetchContent_Declare(googletest URL https://github.com/google/googletest/archive/609281088cfefc76f9d0ce82e1ff6c30cc3591e5.zip)
FetchContent_MakeAvailable(googletest)
add_subdirectory(${ES}/dependencies/submodules/piranha piranha EXCLUDE_FROM_ALL)
add_subdirectory(${ES}/dependencies/submodules/csv-io csvio EXCLUDE_FROM_ALL)
add_subdirectory(${ES}/dependencies/submodules/simple-2d-constraint-solver scs EXCLUDE_FROM_ALL)
file(GLOB CORE_SRC
  ${ES}/src/audio_buffer.cpp ${ES}/src/camshaft.cpp ${ES}/src/crankshaft.cpp ${ES}/src/combustion_chamber.cpp
  ${ES}/src/connecting_rod.cpp ${ES}/src/convolution_filter.cpp ${ES}/src/cylinder_bank.cpp ${ES}/src/cylinder_head.cpp
  ${ES}/src/delay_filter.cpp ${ES}/src/derivative_filter.cpp ${ES}/src/direct_throttle_linkage.cpp ${ES}/src/dynamometer.cpp
  ${ES}/src/engine.cpp ${ES}/src/exhaust_system.cpp ${ES}/src/feedback_comb_filter.cpp ${ES}/src/filter.cpp ${ES}/src/fuel.cpp
  ${ES}/src/function.cpp ${ES}/src/gas_system.cpp ${ES}/src/gaussian_filter.cpp ${ES}/src/governor.cpp ${ES}/src/ignition_module.cpp
  ${ES}/src/impulse_response.cpp ${ES}/src/intake.cpp ${ES}/src/jitter_filter.cpp ${ES}/src/leveling_filter.cpp
  ${ES}/src/low_pass_filter.cpp ${ES}/src/part.cpp ${ES}/src/piston.cpp ${ES}/src/piston_engine_simulator.cpp ${ES}/src/simulator.cpp
  ${ES}/src/standard_valvetrain.cpp ${ES}/src/starter_motor.cpp ${ES}/src/synthesizer.cpp ${ES}/src/throttle.cpp
  ${ES}/src/transmission.cpp ${ES}/src/utilities.cpp ${ES}/src/valvetrain.cpp ${ES}/src/vehicle.cpp
  ${ES}/src/vehicle_drag_constraint.cpp ${ES}/src/vtec_valvetrain.cpp
  ${ES}/scripting/src/channel_types.cpp ${ES}/scripting/src/compiler.cpp ${ES}/scripting/src/engine_context.cpp ${ES}/scripting/src/language_rules.cpp)
add_executable(dyno dyno.cpp ${CORE_SRC})
target_compile_definitions(dyno PRIVATE ATG_ENGINE_SIM_PIRANHA_ENABLED ES_DIR="${ES}")
target_include_directories(dyno PRIVATE ${ES} ${ES}/dependencies/submodules)
target_link_options(dyno PRIVATE -Wl,--allow-multiple-definition)
target_link_libraries(dyno piranha csv-io simple-2d-constraint-solver pthread)
