if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    message(WARNING "current system is Linux")
    if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "aarch64")
        set(cef_prebuilt_path "https://cef-builds.spotifycdn.com/cef_binary_130.1.2%2Bg48f3ef6%2Bchromium-130.0.6723.44_linuxarm64.tar.bz2")
        set(cef_prebuilt_version "cef_binary_130.1.2%2Bg48f3ef6%2Bchromium-130.0.6723.44_linuxarm64.tar.bz2")
    else()
        set(cef_prebuilt_path "https://cef-builds.spotifycdn.com/cef_binary_130.1.2%2Bg48f3ef6%2Bchromium-130.0.6723.44_linux64.tar.bz2")
        set(cef_prebuilt_version "cef_binary_130.1.2%2Bg48f3ef6%2Bchromium-130.0.6723.44_linux64.tar.bz2")
    endif()
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    message(WARNING "current system is Windows")
    set(cef_prebuilt_path "https://github.com/hlwhl/webview_cef/releases/download/prebuilt_cef_bin_linux/webview_cef_bin_0.0.2_101.0.18+chromium-101.0.4951.67_windows64.zip")
    set(cef_prebuilt_version "webview_cef_bin_0.0.2_101.0.18+chromium-101.0.4951.67_windows64")
# elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
#     message(STATUS "current system is MacOS")
#     set(cef_prebuilt_path "")
endif()
set(cef_prebuilt_version_path "https://github.com/hlwhl/webview_cef/releases/download/prebuilt_cef_bin_linux/version.txt")

if(NOT DEFINED WEBVIEW_CEF_STRIP_TOOL)
    if(CMAKE_STRIP)
        set(WEBVIEW_CEF_STRIP_TOOL ${CMAKE_STRIP})
    else()
        find_program(WEBVIEW_CEF_STRIP_TOOL strip)
    endif()
endif()


function(extract_file filename extract_dir)
    message(WARNING "${filename} will extract to ${extract_dir} ...")

    set(temp_dir ${CMAKE_BINARY_DIR}/tmp_for_extract.dir)
    if(EXISTS ${temp_dir})
        file(REMOVE_RECURSE ${temp_dir})
    endif()
    file(MAKE_DIRECTORY ${temp_dir})
    execute_process(COMMAND ${CMAKE_COMMAND} -E tar -xf ${filename}
            WORKING_DIRECTORY ${temp_dir})

    file(GLOB contents "${temp_dir}/*")
    list(LENGTH contents n)
    if(NOT n EQUAL 1 OR NOT IS_DIRECTORY "${contents}")
        set(contents "${temp_dir}")
    endif()

    get_filename_component(contents ${contents} ABSOLUTE)

    file(INSTALL "${contents}/" DESTINATION ${extract_dir})

    file(REMOVE_RECURSE ${temp_dir})
endfunction()

function(download_file url filename)
    message(WARNING "Downloading ${filename} from ${url}")
    file(DOWNLOAD ${url} ${filename} STATUS SHOW_PROGRESS)
endfunction(download_file)

function(strip_cef_binary filepath)
    if(NOT EXISTS ${filepath})
        return()
    endif()
    if(NOT WEBVIEW_CEF_STRIP_TOOL)
        message(WARNING "No strip tool available, skip stripping ${filepath}")
        return()
    endif()
    execute_process(
        COMMAND ${WEBVIEW_CEF_STRIP_TOOL} --strip-unneeded ${filepath}
        RESULT_VARIABLE strip_result
        ERROR_VARIABLE strip_error
    )
    if(NOT strip_result EQUAL 0)
        message(WARNING "Failed to strip ${filepath}: ${strip_error}")
    endif()
endfunction()

function(trim_cef_runtime root_dir)
    set(extra_dirs
        "${root_dir}/tests"
        "${root_dir}/tools"
        "${root_dir}/libcef_dll/Debug"
        "${root_dir}/libcef_dll_wrapper/Debug"
        "${root_dir}/samples"
    )
    foreach(dir_path ${extra_dirs})
        if(EXISTS ${dir_path})
            file(REMOVE_RECURSE ${dir_path})
        endif()
    endforeach()

    set(strip_targets
        "${root_dir}/Release/libcef.so"
        "${root_dir}/Release/libEGL.so"
        "${root_dir}/Release/libGLESv2.so"
        "${root_dir}/Release/libvk_swiftshader.so"
        "${root_dir}/Release/chrome-sandbox"
        "${root_dir}/Release/swiftshader/libEGL.so"
        "${root_dir}/Release/swiftshader/libGLESv2.so"
        "${root_dir}/Release/swiftshader/libvk_swiftshader.so"
    )
    foreach(target_file ${strip_targets})
        strip_cef_binary(${target_file})
    endforeach()
endfunction()

function(prepare_prebuilt_files filepath)
    set(need_download FALSE)

    if(NOT EXISTS ${filepath})
        message(WARNING "No ${filepath} found")
        set(need_download TRUE)
    else()
        if(NOT EXISTS ${filepath}/version.txt)
            message(WARNING "No ${filepath}/version.txt found")
            set(need_download TRUE)
        else()
            file(READ ${filepath}/version.txt local_version)
            if(local_version STREQUAL cef_prebuilt_version)
                if(EXISTS ${filepath}/cmake/FindCEF.cmake)
                    message(WARNING "No need to update ${filepath}")
                else()
                    message(WARNING "CEF cmake files missing in ${filepath}, need to redownload")
                    set(need_download TRUE)
                endif()
            else()
                set(need_download TRUE)
            endif()
            file(REMOVE_RECURSE ${filepath}/new_version.txt)
        endif()
    endif()

    if(need_download)
        message(WARNING "Need to update ${filepath}")
        file(REMOVE_RECURSE ${filepath}/cmake ${filepath}/Debug ${filepath}/Release ${filepath}/Resources ${filepath}/libcef_dll ${filepath}/libcef_dll_wrapper)
        download_file(${cef_prebuilt_path} ${CMAKE_CURRENT_SOURCE_DIR}/prebuilt.zip)
        file(MAKE_DIRECTORY ${filepath})
        extract_file(${CMAKE_CURRENT_SOURCE_DIR}/prebuilt.zip ${filepath})
        trim_cef_runtime(${filepath})

        ## Needed for making it run on arm64 Linux (makes it check for arm64 or aarch64 instead of just arm64)
        if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
            execute_process(
                COMMAND sed -i "s/\"\\\${CMAKE_HOST_SYSTEM_PROCESSOR}\" STREQUAL \"arm64\"/(\"\\\${CMAKE_HOST_SYSTEM_PROCESSOR}\" STREQUAL \"arm64\" OR \"\\\${CMAKE_HOST_SYSTEM_PROCESSOR}\" STREQUAL \"aarch64\")/" ${filepath}/cmake/cef_variables.cmake
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            )
        endif()

        file(WRITE "${filepath}/version.txt" "${cef_prebuilt_version}")
        file(REMOVE_RECURSE ${CMAKE_CURRENT_SOURCE_DIR}/prebuilt.zip)
    endif()
endfunction(prepare_prebuilt_files)
