# This file is part of GCC.
#
# GCC is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 3, or (at your option) any later
# version.
#
# GCC is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with GCC; see the file COPYING3.  If not see
# <http://www.gnu.org/licenses/>.
#
# Contributed by Andreas Simbuerger <simbuerg@fim.uni-passau.de>

# CLOOG_INIT_FLAGS ()
# -------------------------
# Provide configure switches for CLooG support.
# Initialize clooglibs/clooginc according to the user input.
AC_DEFUN([CLOOG_INIT_FLAGS],
[
  AC_ARG_WITH(cloog,
    [AS_HELP_STRING(
      [--with-cloog=PATH],
      [Specify prefix directory for the installed CLooG-PPL package.
       Equivalent to --with-cloog-include=PATH/include
       plus --with-cloog-lib=PATH/lib])])
  AC_ARG_WITH(cloog_include,
    [AS_HELP_STRING(
      [--with-cloog-include=PATH],
      [Specify directory for installed CLooG include files])])
  AC_ARG_WITH(cloog_lib,
    [AS_HELP_STRING(
      [--with-cloog-lib=PATH],
      [Specify the directory for the installed CLooG library])])
  
  AC_ARG_ENABLE(cloog-version-check,
    [AS_HELP_STRING(
      [--disable-cloog-version-check],
      [disable check for CLooG version])],
    ENABLE_CLOOG_CHECK=$enableval,
    ENABLE_CLOOG_CHECK=yes)
  
  # Initialize clooglibs and clooginc.
  case $with_cloog in
    no)
      clooglibs=
      clooginc=
      ;;
    "" | yes)
      ;;
    *)
      clooglibs="-L$with_cloog/lib"
      clooginc="-I$with_cloog/include"
      ;;
  esac
  if test "x${with_cloog_include}" != x ; then
    clooginc="-I$with_cloog_include"
  fi
  if test "x${with_cloog_lib}" != x; then
    clooglibs="-L$with_cloog_lib"
  fi

  dnl Flags needed for CLOOG
  AC_SUBST(clooglibs)
  AC_SUBST(clooginc)
]
)

# CLOOG_REQUESTED (ACTION-IF-REQUESTED, ACTION-IF-NOT)
# ----------------------------------------------------
# Provide actions for failed CLooG detection.
AC_DEFUN([CLOOG_REQUESTED],
[
  AC_REQUIRE([CLOOG_INIT_FLAGS])

  if test "x${with_cloog}" != x \
    || test "x${with_cloog_include}" != x \
    || test "x${with_cloog_lib}" != x ; then
    $1
  else
    $2
  fi
]
)

# _CLOOG_ORG_PROG ()
# ------------------
# Helper for detecting CLooG.org's backend.
m4_define([_CLOOG_ORG_PROG],[AC_LANG_PROGRAM(
  [#include <cloog/cloog.h>],
  [cloog_version ()])])

# _CLOOG_PPL_LEGACY_PROG ()
# -------------------------
# Helper for detecting CLooG-Legacy (CLooG-PPL).
m4_define([_CLOOG_PPL_LEGACY_PROG], [AC_LANG_PROGRAM(
  [#include <cloog/cloog.h>],
  [ppl_version_major ()])])

# CLOOG_FIND_FLAGS ()
# ------------------
# Detect the used CLooG-backend and set clooginc/clooglibs/cloog_org.
# Preference: CLooG-PPL (Legacy) > CLooG-ISL > CLooG-PPL
AC_DEFUN([CLOOG_FIND_FLAGS],
[
  AC_REQUIRE([CLOOG_INIT_FLAGS])

  _cloog_saved_CFLAGS=$CFLAGS
  _cloog_saved_CPPFLAGS=$CPPFLAGS
  _cloog_saved_LDFLAGS=$LDFLAGS
  _cloog_saved_LIBS=$LIBS

  _clooglegacyinc="-DCLOOG_PPL_BACKEND"
  _cloogorginc="-DCLOOG_INT_GMP -DCLOOG_ORG"
 
  dnl clooglibs & clooginc may have been initialized by CLOOG_INIT_FLAGS.
  CFLAGS="${CFLAGS} ${clooginc} ${pplinc} ${gmpinc}"
  CPPFLAGS="${CPPFLAGS} ${_clooglegacyinc} ${_cloogorginc}"
  LDFLAGS="${LDFLAGS} ${clooglibs}"

  AC_CACHE_CHECK([for installed CLooG],
                 [gcc_cv_cloog_type],
    [LIBS="-lcloog ${_cloog_saved_LIBS}"
     AC_LINK_IFELSE([_CLOOG_PPL_LEGACY_PROG],
      [gcc_cv_cloog_type="PPL Legacy"],
      [LIBS="-lcloog-isl -lisl ${_cloog_saved_LIBS}"
       AC_LINK_IFELSE([_CLOOG_ORG_PROG],
        [gcc_cv_cloog_type=ISL],
        [LIBS="-lcloog-ppl ${_cloog_saved_LIBS}"
         AC_LINK_IFELSE([_CLOOG_ORG_PROG],
          [gcc_cv_cloog_type=PPL],
          [gcc_cv_cloog_type=no])])])])

  case $gcc_cv_cloog_type in
    "PPL Legacy")
      clooginc="${clooginc} ${_clooglegacyinc}"
      clooglibs="${clooglibs} -lcloog"
      cloog_org=no
      ;;
    "ISL")
      clooginc="${clooginc} ${_cloogorginc}"
      clooglibs="${clooglibs} -lcloog-isl"
      cloog_org=yes
      ;;
    "PPL")
      clooginc="${clooginc} ${_cloogorginc}"
      clooglibs="${clooglibs} -lcloog-ppl"
      cloog_org=yes
      ;;
    *)
      clooglibs=
      clooginc=
      cloog_org=
      ;;
  esac

  LIBS=$_cloog_saved_LIBS
  CFLAGS=$_cloog_saved_CFLAGS
  CPPFLAGS=$_cloog_saved_CPPFLAGS
  LDFLAGS=$_cloog_saved_LDFLAGS
]
)

# _CLOOG_CHECK_CT_PROG(MAJOR, MINOR, REVISION)
# --------------------------------------------
# Helper for verifying CLooG's compile time version.
m4_define([_CLOOG_CHECK_CT_PROG],[AC_LANG_PROGRAM(
  [#include "cloog/cloog.h"],
  [#if CLOOG_VERSION_MAJOR != $1 \
    || CLOOG_VERSION_MINOR != $2 \
    || CLOOG_VERSION_REVISION < $3
    choke me
   #endif])])

# _CLOOG_CHECK_RT_PROG ()
# -----------------------
# Helper for verifying that CLooG's compile time version
# matches the run time version.
m4_define([_CLOOG_CHECK_RT_PROG],[AC_LANG_PROGRAM(
  [#include "cloog/cloog.h"],
  [if ((cloog_version_major () != CLOOG_VERSION_MAJOR)
    && (cloog_version_minor () != CLOOG_VERSION_MINOR)
    && (cloog_version_revision () != CLOOG_VERSION_REVISION))
    {
      return 1;
    }])])

# CLOOG_CHECK_VERSION CLOOG_CHECK_VERSION (MAJOR, MINOR, REVISION)
# ----------------------------------------------------------------
# Test the found CLooG to be exact of version MAJOR.MINOR and at least
# REVISION.
# If we're using the old CLooG-PPL (Legacy), the old version check will
# be executed (Ignores the provided version information).
AC_DEFUN([CLOOG_CHECK_VERSION],
[
  AC_REQUIRE([CLOOG_FIND_FLAGS])

  if test "${ENABLE_CLOOG_CHECK}" = yes ; then
    _cloog_saved_CFLAGS=$CFLAGS
    _cloog_saved_LDFLAGS=$LDFLAGS

    CFLAGS="${_cloog_saved_CFLAGS} ${clooginc} ${pplinc} ${gmpinc}"
    LDFLAGS="${_cloog_saved_LDFLAGS} ${clooglibs}"

    if test "${cloog_org}" = yes ; then
      AC_CACHE_CHECK([for verison $1.$2.$3 of CLooG],
        [gcc_cv_cloog_ct_0_14_0],
        [AC_COMPILE_IFELSE([_CLOOG_CHECK_CT_PROG($1,$2,$3)],
          [gcc_cv_cloog_ct_0_14_0=yes],
          [gcc_cv_cloog_ct_0_14_0=no])])
    elif test "${cloog_org}" = no ; then
      AC_CACHE_CHECK([for version 0.15.5 (or later revision) of CLooG],
        [gcc_cv_cloog_ct_0_15_5],
        [AC_COMPILE_IFELSE([_CLOOG_CHECK_CT_PROG(0,15,5)],
          [AC_COMPILE_IFELSE([_CLOOG_CHECK_CT_PROG(0,15,9)],
           [gcc_cv_cloog_ct_0_15_5=yes],
            [gcc_cv_cloog_ct_0_15_5="buggy but acceptable"])],
          [gcc_cv_cloog_ct_0_15_5=no])])
    fi

    CFLAGS=$_cloog_saved_CFLAGS
    LDFLAGS=$_cloog_saved_LDFLAGS
  fi
]
)

# CLOOG_IF_FAILED (ACTION-IF-FAILED)
# ----------------------------------
# Executes ACTION-IF-FAILED, if GRAPHITE was requested and
# the checks failed.
AC_DEFUN([CLOOG_IF_FAILED],
[
  CLOOG_REQUESTED([graphite_requested=yes], [graphite_requested=no])
  
  if test "${gcc_cv_cloog_ct_0_14_0}" = no \
    || test "${gcc_cv_cloog_rt_0_14_0}" = no \
    || test "${gcc_cv_cloog_ct_0_15_5}" = no; then
    clooglibs=
    clooginc=
  fi

  if test "${graphite_requested}" = yes \
    && test "x${clooglibs}" = x \
    && test "x${clooginc}" = x ; then
    $1
  fi
]
)
