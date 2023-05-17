FROM amazon/aws-lambda-nodejs:16 as builder

ARG DUCKDB_VERSION=0.8.0

# Install dependencies
RUN yum update -y && \
  yum install git zip ninja-build make gcc-c++ openssl11-devel python-pip python3 -y && \
  yum remove cmake -y && \
  pip install cmake --upgrade

# Get DuckDB sources
RUN mkdir -p /tmp/from-git && cd /tmp/from-git && git clone --depth 1 --branch "v$DUCKDB_VERSION" https://github.com/duckdb/duckdb.git && cd duckdb

# Copy custom Makefile (less parallelism)
COPY src/Makefile /tmp/from-git/duckdb/tools/nodejs/Makefile

# Copy custom configure.py (add httpfs extension)
COPY src/configure.py /tmp/from-git/duckdb/tools/nodejs/configure.py

# Configure
RUN cd /tmp/from-git/duckdb/tools/nodejs && ./configure && GEN=ninja EXTENSION_STATIC_BUILD=1 BUILD_TPCH=1 BUILD_HTTPFS=1 STATIC_OPENSSL=1 BUILD_NODE=1 CMAKE_BUILD_PARALLEL_LEVEL=$(nproc) make

# Copy local binding definition
COPY src/lib/duckdb-binding.js /tmp/from-git/duckdb/tools/nodejs/lib/duckdb-binding.js

# Copy updated package.json
COPY src/package.json /tmp/from-git/duckdb/tools/nodejs/package.json

# Create zip file with layer contents
RUN mkdir -p /tmp/build/nodejs/node_modules/duckdb/lib /tmp/build/nodejs/node_modules/duckdb/release /tmp/release && \
  cp /tmp/from-git/duckdb/tools/nodejs/lib/*.js /tmp/build/nodejs/node_modules/duckdb/lib && \
  cp /tmp/from-git/duckdb/tools/nodejs/package.json /tmp/build/nodejs/node_modules/duckdb/package.json && \
  cp /tmp/from-git/duckdb/tools/nodejs/duckdb.js /tmp/build/nodejs/node_modules/duckdb/duckdb.js && \
  cp /tmp/from-git/duckdb/tools/nodejs/build/Release/duckdb.node /tmp/build/nodejs/node_modules/duckdb/release/duckdb.node && \
  cd /tmp/build/nodejs/node_modules/duckdb && npm version ${DUCKDB_VERSION} || true && \
  cd /tmp/build && zip -q -r /tmp/release/duckdb-layer.zip .
