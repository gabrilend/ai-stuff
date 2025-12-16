#!/bin/bash
# {{{ setup_env
# Environment setup for City of Heroes development

DIR="${1:-/mnt/mtwo/programming/ai-stuff/games/city-of-chat}"
export COH_LIBS_DIR="${DIR}/libs"

# Add library paths
export PATH="${COH_LIBS_DIR}/postgresql/bin:${COH_LIBS_DIR}/openssl/bin:$PATH"
export LD_LIBRARY_PATH="${COH_LIBS_DIR}/postgresql/lib:${COH_LIBS_DIR}/openssl/lib:${COH_LIBS_DIR}/boost/lib:${COH_LIBS_DIR}/zlib/lib:$LD_LIBRARY_PATH"

# C++ build environment
export CPPFLAGS="-I${COH_LIBS_DIR}/postgresql/include -I${COH_LIBS_DIR}/openssl/include -I${COH_LIBS_DIR}/boost/include -I${COH_LIBS_DIR}/zlib/include $CPPFLAGS"
export LDFLAGS="-L${COH_LIBS_DIR}/postgresql/lib -L${COH_LIBS_DIR}/openssl/lib -L${COH_LIBS_DIR}/boost/lib -L${COH_LIBS_DIR}/zlib/lib $LDFLAGS"

# Database setup
export PGDATA="${DIR}/data/postgresql"
export PGHOST="localhost"
export PGPORT="5432"

echo "City of Heroes development environment configured"
echo "Libraries installed in: $COH_LIBS_DIR"
echo ""
echo "To initialize PostgreSQL database:"
echo "  ${COH_LIBS_DIR}/postgresql/bin/initdb -D $PGDATA"
echo ""
echo "To start PostgreSQL:"
echo "  ${COH_LIBS_DIR}/postgresql/bin/pg_ctl -D $PGDATA -l ${DIR}/data/postgresql.log start"
echo ""
# }}}
