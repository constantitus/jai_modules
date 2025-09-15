#!/bin/sh

# Version and commit headers for angle
angle/src/program_serialize_data_version.py ANGLEShaderProgramVersion.h shader_compiler_files
angle/src/commit_id.py gen angle_commit.h

# Version header for astc-encoder
version_file="astc-encoder/Source/astcenccli_version.h"
echo "#pragma once" > $version_file
echo "#define VERSION_STRING \"0.0.0\"" >> $version_file
echo "#define YEAR_STRING \"2021\"" >> $version_file

