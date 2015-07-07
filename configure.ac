AC_PREREQ(2.61)
AC_INIT([dydisnix-geninfra-avahi], m4_esyscmd([echo -n $(cat ./version)$VERSION_SUFFIX]))
AC_CONFIG_AUX_DIR([config])
AM_INIT_AUTOMAKE([1.9 tar-pax -Wall -Werror -Wno-extra-portability])

# Checks for installed programs
AC_DEFUN([NEED_PROG],
[
AC_PATH_PROG($1, $2)
if test -z "$$1"; then
    AC_MSG_ERROR([$2 is required])
fi
])

# Checks for programs
AC_PROG_CC
AM_PROG_CC_C_O
AC_PROG_INSTALL
PKG_PROG_PKG_CONFIG
NEED_PROG(avahi_publish_service, avahi-publish-service)

# Checks for avahi client libraries
AVAHI_CLIENT_REQUIRED=0.6.28
PKG_CHECK_MODULES(AVAHI_CLIENT, avahi-client >= $AVAHI_CLIENT_REQUIRED)
AC_SUBST(AVAHI_CLIENT_CFLAGS)
AC_SUBST(AVAHI_CLIENT_LIBS)

# Output
AC_CONFIG_FILES([
Makefile
src/Makefile
scripts/dydisnix-publishinfra-avahi
scripts/Makefile
])
AC_OUTPUT
