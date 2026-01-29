AC_INIT([curl-impersonate], [1.0.0], [infinitesheldon@gmail.com])

AC_CANONICAL_BUILD
AC_CANONICAL_HOST

AC_PROG_CC
AC_PROG_CXX

AC_CHECK_TOOL([STRIP], [strip])

AC_ARG_ENABLE([static],
    [AS_HELP_STRING([--enable-static],
        [Build curl-impersonate statically with libcurl-impersonate])],
    [AC_SUBST([static_build], ["$enableval"])],
    [AC_SUBST([static_build], ["no"])])

# Path to CA certificates.
# These options will be passed as-is to curl's configure script.
# Useful when cross compiling, since curl's configure script doesn't know
# where to look for these files in that case.
AC_ARG_WITH([ca-bundle],
    [AS_HELP_STRING([--with-ca-bundle=FILE],
        [Path to be passed to curl's --with-ca-bundle configure option. \
         Useful when cross compiling. \
         Relevant only for the Chrome build.])],
    [AC_SUBST([with_ca_bundle], ["$withval"])],
    [AC_SUBST([with_ca_bundle], [""])])
AC_ARG_WITH([ca-path],
    [AS_HELP_STRING([--with-ca-path=DIRECTORY],
        [Path to be passed to curl's --with-ca-path configure option. \
         Useful when cross compiling. \
         Relevant only for the chrome build.])],
    [AC_SUBST([with_ca_path], ["$withval"])],
    [AC_SUBST([with_ca_path], [""])])

# BoringSSL requires cmake 3.5+, which is sometimes available under
# "cmake3" instead of "cmake"
AC_CHECK_PROGS([cmake], [cmake3 cmake])

AC_CHECK_PROGS([ninja], [ninja ninja-build])

AC_CONFIG_FILES([Makefile])

AC_OUTPUT
