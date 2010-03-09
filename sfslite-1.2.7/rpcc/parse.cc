/* A Bison parser, made by GNU Bison 2.3.  */

/* Skeleton implementation for Bison's Yacc-like parsers in C

   Copyright (C) 1984, 1989, 1990, 2000, 2001, 2002, 2003, 2004, 2005, 2006
   Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* C LALR(1) parser skeleton written by Richard Stallman, by
   simplifying the original so-called "semantic" parser.  */

/* All symbols defined below should begin with yy or YY, to avoid
   infringing on user name space.  This should be done even for local
   variables, as they might otherwise be expanded by user macros.
   There are some unavoidable exceptions within include files to
   define necessary library symbols; they are noted "INFRINGES ON
   USER NAME SPACE" below.  */

/* Identify Bison output.  */
#define YYBISON 1

/* Bison version.  */
#define YYBISON_VERSION "2.3"

/* Skeleton name.  */
#define YYSKELETON_NAME "yacc.c"

/* Pure parsers.  */
#define YYPURE 0

/* Using locations.  */
#define YYLSP_NEEDED 0



/* Tokens.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
   /* Put the tokens into the symbol table, so that GDB and other debuggers
      know about them.  */
   enum yytokentype {
     T_ID = 258,
     T_NUM = 259,
     T_CONST = 260,
     T_STRUCT = 261,
     T_UNION = 262,
     T_ENUM = 263,
     T_TYPEDEF = 264,
     T_PROGRAM = 265,
     T_NAMESPACE = 266,
     T_UNSIGNED = 267,
     T_INT = 268,
     T_HYPER = 269,
     T_DOUBLE = 270,
     T_QUADRUPLE = 271,
     T_VOID = 272,
     T_VERSION = 273,
     T_SWITCH = 274,
     T_CASE = 275,
     T_DEFAULT = 276,
     T_OPAQUE = 277,
     T_STRING = 278
   };
#endif
/* Tokens.  */
#define T_ID 258
#define T_NUM 259
#define T_CONST 260
#define T_STRUCT 261
#define T_UNION 262
#define T_ENUM 263
#define T_TYPEDEF 264
#define T_PROGRAM 265
#define T_NAMESPACE 266
#define T_UNSIGNED 267
#define T_INT 268
#define T_HYPER 269
#define T_DOUBLE 270
#define T_QUADRUPLE 271
#define T_VOID 272
#define T_VERSION 273
#define T_SWITCH 274
#define T_CASE 275
#define T_DEFAULT 276
#define T_OPAQUE 277
#define T_STRING 278




/* Copy the first part of user declarations.  */
#line 24 "/home/max/sfslite/1.2/rpcc/parse.yy"

#include "rpcc.h"
#define YYSTYPE YYSTYPE

static int proc_compare (const void *, const void *);
static int vers_compare (const void *, const void *);
static str getnewid (str);
static str getid (str);


/* Enabling traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif

/* Enabling verbose error messages.  */
#ifdef YYERROR_VERBOSE
# undef YYERROR_VERBOSE
# define YYERROR_VERBOSE 1
#else
# define YYERROR_VERBOSE 0
#endif

/* Enabling the token table.  */
#ifndef YYTOKEN_TABLE
# define YYTOKEN_TABLE 0
#endif

#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
typedef int YYSTYPE;
# define yystype YYSTYPE /* obsolescent; will be withdrawn */
# define YYSTYPE_IS_DECLARED 1
# define YYSTYPE_IS_TRIVIAL 1
#endif



/* Copy the second part of user declarations.  */


/* Line 216 of yacc.c.  */
#line 162 "y.tab.c"

#ifdef short
# undef short
#endif

#ifdef YYTYPE_UINT8
typedef YYTYPE_UINT8 yytype_uint8;
#else
typedef unsigned char yytype_uint8;
#endif

#ifdef YYTYPE_INT8
typedef YYTYPE_INT8 yytype_int8;
#elif (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
typedef signed char yytype_int8;
#else
typedef short int yytype_int8;
#endif

#ifdef YYTYPE_UINT16
typedef YYTYPE_UINT16 yytype_uint16;
#else
typedef unsigned short int yytype_uint16;
#endif

#ifdef YYTYPE_INT16
typedef YYTYPE_INT16 yytype_int16;
#else
typedef short int yytype_int16;
#endif

#ifndef YYSIZE_T
# ifdef __SIZE_TYPE__
#  define YYSIZE_T __SIZE_TYPE__
# elif defined size_t
#  define YYSIZE_T size_t
# elif ! defined YYSIZE_T && (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
#  include <stddef.h> /* INFRINGES ON USER NAME SPACE */
#  define YYSIZE_T size_t
# else
#  define YYSIZE_T unsigned int
# endif
#endif

#define YYSIZE_MAXIMUM ((YYSIZE_T) -1)

#ifndef YY_
# if YYENABLE_NLS
#  if ENABLE_NLS
#   include <libintl.h> /* INFRINGES ON USER NAME SPACE */
#   define YY_(msgid) dgettext ("bison-runtime", msgid)
#  endif
# endif
# ifndef YY_
#  define YY_(msgid) msgid
# endif
#endif

/* Suppress unused-variable warnings by "using" E.  */
#if ! defined lint || defined __GNUC__
# define YYUSE(e) ((void) (e))
#else
# define YYUSE(e) /* empty */
#endif

/* Identity function, used to suppress warnings about constant conditions.  */
#ifndef lint
# define YYID(n) (n)
#else
#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
static int
YYID (int i)
#else
static int
YYID (i)
    int i;
#endif
{
  return i;
}
#endif

#if ! defined yyoverflow || YYERROR_VERBOSE

/* The parser invokes alloca or malloc; define the necessary symbols.  */

# ifdef YYSTACK_USE_ALLOCA
#  if YYSTACK_USE_ALLOCA
#   ifdef __GNUC__
#    define YYSTACK_ALLOC __builtin_alloca
#   elif defined __BUILTIN_VA_ARG_INCR
#    include <alloca.h> /* INFRINGES ON USER NAME SPACE */
#   elif defined _AIX
#    define YYSTACK_ALLOC __alloca
#   elif defined _MSC_VER
#    include <malloc.h> /* INFRINGES ON USER NAME SPACE */
#    define alloca _alloca
#   else
#    define YYSTACK_ALLOC alloca
#    if ! defined _ALLOCA_H && ! defined _STDLIB_H && (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
#     include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
#     ifndef _STDLIB_H
#      define _STDLIB_H 1
#     endif
#    endif
#   endif
#  endif
# endif

# ifdef YYSTACK_ALLOC
   /* Pacify GCC's `empty if-body' warning.  */
#  define YYSTACK_FREE(Ptr) do { /* empty */; } while (YYID (0))
#  ifndef YYSTACK_ALLOC_MAXIMUM
    /* The OS might guarantee only one guard page at the bottom of the stack,
       and a page size can be as small as 4096 bytes.  So we cannot safely
       invoke alloca (N) if N exceeds 4096.  Use a slightly smaller number
       to allow for a few compiler-allocated temporary stack slots.  */
#   define YYSTACK_ALLOC_MAXIMUM 4032 /* reasonable circa 2006 */
#  endif
# else
#  define YYSTACK_ALLOC YYMALLOC
#  define YYSTACK_FREE YYFREE
#  ifndef YYSTACK_ALLOC_MAXIMUM
#   define YYSTACK_ALLOC_MAXIMUM YYSIZE_MAXIMUM
#  endif
#  if (defined __cplusplus && ! defined _STDLIB_H \
       && ! ((defined YYMALLOC || defined malloc) \
	     && (defined YYFREE || defined free)))
#   include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
#   ifndef _STDLIB_H
#    define _STDLIB_H 1
#   endif
#  endif
#  ifndef YYMALLOC
#   define YYMALLOC malloc
#   if ! defined malloc && ! defined _STDLIB_H && (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
void *malloc (YYSIZE_T); /* INFRINGES ON USER NAME SPACE */
#   endif
#  endif
#  ifndef YYFREE
#   define YYFREE free
#   if ! defined free && ! defined _STDLIB_H && (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
void free (void *); /* INFRINGES ON USER NAME SPACE */
#   endif
#  endif
# endif
#endif /* ! defined yyoverflow || YYERROR_VERBOSE */


#if (! defined yyoverflow \
     && (! defined __cplusplus \
	 || (defined YYSTYPE_IS_TRIVIAL && YYSTYPE_IS_TRIVIAL)))

/* A type that is properly aligned for any stack member.  */
struct yyalloc
{
  yytype_int16 yyss;
  YYSTYPE yyvs;
  };

/* The size of the maximum gap between one aligned stack and the next.  */
# define YYSTACK_GAP_MAXIMUM (sizeof (struct yyalloc) - 1)

/* The size of an array large to enough to hold all stacks, each with
   N elements.  */
# define YYSTACK_BYTES(N) \
     ((N) * (sizeof (yytype_int16) + sizeof (YYSTYPE)) \
      + YYSTACK_GAP_MAXIMUM)

/* Copy COUNT objects from FROM to TO.  The source and destination do
   not overlap.  */
# ifndef YYCOPY
#  if defined __GNUC__ && 1 < __GNUC__
#   define YYCOPY(To, From, Count) \
      __builtin_memcpy (To, From, (Count) * sizeof (*(From)))
#  else
#   define YYCOPY(To, From, Count)		\
      do					\
	{					\
	  YYSIZE_T yyi;				\
	  for (yyi = 0; yyi < (Count); yyi++)	\
	    (To)[yyi] = (From)[yyi];		\
	}					\
      while (YYID (0))
#  endif
# endif

/* Relocate STACK from its old location to the new one.  The
   local variables YYSIZE and YYSTACKSIZE give the old and new number of
   elements in the stack, and YYPTR gives the new location of the
   stack.  Advance YYPTR to a properly aligned location for the next
   stack.  */
# define YYSTACK_RELOCATE(Stack)					\
    do									\
      {									\
	YYSIZE_T yynewbytes;						\
	YYCOPY (&yyptr->Stack, Stack, yysize);				\
	Stack = &yyptr->Stack;						\
	yynewbytes = yystacksize * sizeof (*Stack) + YYSTACK_GAP_MAXIMUM; \
	yyptr += yynewbytes / sizeof (*yyptr);				\
      }									\
    while (YYID (0))

#endif

/* YYFINAL -- State number of the termination state.  */
#define YYFINAL  2
/* YYLAST -- Last index in YYTABLE.  */
#define YYLAST   188

/* YYNTOKENS -- Number of terminals.  */
#define YYNTOKENS  37
/* YYNNTS -- Number of nonterminals.  */
#define YYNNTS  41
/* YYNRULES -- Number of rules.  */
#define YYNRULES  79
/* YYNRULES -- Number of states.  */
#define YYNSTATES  164

/* YYTRANSLATE(YYLEX) -- Bison symbol number corresponding to YYLEX.  */
#define YYUNDEFTOK  2
#define YYMAXUTOK   278

#define YYTRANSLATE(YYX)						\
  ((unsigned int) (YYX) <= YYMAXUTOK ? yytranslate[YYX] : YYUNDEFTOK)

/* YYTRANSLATE[YYLEX] -- Bison symbol number corresponding to YYLEX.  */
static const yytype_uint8 yytranslate[] =
{
       0,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
      29,    30,    32,     2,    28,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,    31,    25,
      35,    24,    36,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,    33,     2,    34,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,    26,     2,    27,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     1,     2,     3,     4,
       5,     6,     7,     8,     9,    10,    11,    12,    13,    14,
      15,    16,    17,    18,    19,    20,    21,    22,    23
};

#if YYDEBUG
/* YYPRHS[YYN] -- Index of the first RHS symbol of rule number YYN in
   YYRHS.  */
static const yytype_uint16 yyprhs[] =
{
       0,     0,     3,     4,     5,     9,    11,    13,    15,    17,
      19,    21,    23,    26,    30,    36,    37,    46,    47,    49,
      50,    58,    59,    72,    73,    83,    84,    92,    94,    97,
      99,   102,   103,   113,   115,   118,   127,   129,   132,   135,
     137,   140,   144,   147,   149,   152,   154,   157,   159,   161,
     165,   167,   171,   173,   177,   181,   186,   193,   200,   207,
     214,   221,   227,   233,   239,   241,   243,   245,   247,   249,
     251,   254,   256,   259,   261,   263,   265,   267,   269,   271
};

/* YYRHS -- A `-1'-separated list of the rules' RHS.  */
static const yytype_int8 yyrhs[] =
{
      38,     0,    -1,    -1,    -1,    38,    39,    40,    -1,    42,
      -1,    43,    -1,    46,    -1,    41,    -1,    48,    -1,    50,
      -1,    52,    -1,     9,    70,    -1,     9,     6,    70,    -1,
       5,    76,    24,    74,    25,    -1,    -1,     8,    76,    26,
      44,    67,    45,    27,    25,    -1,    -1,    28,    -1,    -1,
       6,    76,    26,    47,    65,    27,    25,    -1,    -1,     7,
      76,    19,    29,    72,     3,    30,    26,    49,    60,    27,
      25,    -1,    -1,    10,    76,    26,    51,    55,    27,    24,
      75,    25,    -1,    -1,    11,    76,    26,    53,    54,    27,
      25,    -1,    50,    -1,    54,    50,    -1,    56,    -1,    55,
      56,    -1,    -1,    18,    76,    26,    57,    58,    27,    24,
      75,    25,    -1,    59,    -1,    58,    59,    -1,    71,    76,
      29,    71,    30,    24,    75,    25,    -1,    61,    -1,    60,
      61,    -1,    62,    64,    -1,    63,    -1,    62,    63,    -1,
      20,    74,    31,    -1,    21,    31,    -1,    70,    -1,    17,
      25,    -1,    66,    -1,    65,    66,    -1,    70,    -1,    68,
      -1,    67,    28,    68,    -1,    69,    -1,    76,    24,    74,
      -1,    76,    -1,    72,     3,    25,    -1,    23,     3,    25,
      -1,    72,    32,     3,    25,    -1,    72,     3,    33,    74,
      34,    25,    -1,    22,     3,    33,    74,    34,    25,    -1,
      72,     3,    35,    74,    36,    25,    -1,    23,     3,    35,
      74,    36,    25,    -1,    22,     3,    35,    74,    36,    25,
      -1,    72,     3,    35,    36,    25,    -1,    23,     3,    35,
      36,    25,    -1,    22,     3,    35,    36,    25,    -1,    72,
      -1,    17,    -1,    73,    -1,    77,    -1,    12,    -1,    13,
      -1,    12,    13,    -1,    14,    -1,    12,    14,    -1,    15,
      -1,    16,    -1,    77,    -1,     4,    -1,     4,    -1,     3,
      -1,     3,    -1
};

/* YYRLINE[YYN] -- source line where rule number YYN was defined.  */
static const yytype_uint16 yyrline[] =
{
       0,    66,    66,    67,    67,    70,    71,    72,    73,    74,
      75,    76,    79,    86,    96,   106,   105,   114,   115,   119,
     118,   128,   127,   139,   138,   153,   152,   162,   162,   165,
     165,   169,   168,   184,   184,   187,   199,   199,   202,   205,
     205,   208,   215,   223,   230,   240,   240,   243,   247,   248,
     251,   255,   256,   259,   261,   266,   268,   271,   274,   276,
     278,   280,   283,   286,   291,   291,   294,   294,   297,   298,
     299,   300,   301,   302,   303,   306,   306,   309,   312,   315
};
#endif

#if YYDEBUG || YYERROR_VERBOSE || YYTOKEN_TABLE
/* YYTNAME[SYMBOL-NUM] -- String name of the symbol SYMBOL-NUM.
   First, the terminals, then, starting at YYNTOKENS, nonterminals.  */
static const char *const yytname[] =
{
  "$end", "error", "$undefined", "T_ID", "T_NUM", "T_CONST", "T_STRUCT",
  "T_UNION", "T_ENUM", "T_TYPEDEF", "T_PROGRAM", "T_NAMESPACE",
  "T_UNSIGNED", "T_INT", "T_HYPER", "T_DOUBLE", "T_QUADRUPLE", "T_VOID",
  "T_VERSION", "T_SWITCH", "T_CASE", "T_DEFAULT", "T_OPAQUE", "T_STRING",
  "'='", "';'", "'{'", "'}'", "','", "'('", "')'", "':'", "'*'", "'['",
  "']'", "'<'", "'>'", "$accept", "file", "@1", "definition", "def_type",
  "def_const", "def_enum", "@2", "comma_warn", "def_struct", "@3",
  "def_union", "@4", "def_program", "@5", "def_namespace", "@6",
  "program_list", "version_list", "version_decl", "@7", "proc_list",
  "proc_decl", "union_taglist", "union_tag", "union_caselist",
  "union_case", "union_decl", "struct_decllist", "struct_decl",
  "enum_taglist", "enum_tag", "enum_cnstag", "declaration", "type_or_void",
  "type", "base_type", "value", "number", "newid", "id", 0
};
#endif

# ifdef YYPRINT
/* YYTOKNUM[YYLEX-NUM] -- Internal token number corresponding to
   token YYLEX-NUM.  */
static const yytype_uint16 yytoknum[] =
{
       0,   256,   257,   258,   259,   260,   261,   262,   263,   264,
     265,   266,   267,   268,   269,   270,   271,   272,   273,   274,
     275,   276,   277,   278,    61,    59,   123,   125,    44,    40,
      41,    58,    42,    91,    93,    60,    62
};
# endif

/* YYR1[YYN] -- Symbol number of symbol that rule YYN derives.  */
static const yytype_uint8 yyr1[] =
{
       0,    37,    38,    39,    38,    40,    40,    40,    40,    40,
      40,    40,    41,    41,    42,    44,    43,    45,    45,    47,
      46,    49,    48,    51,    50,    53,    52,    54,    54,    55,
      55,    57,    56,    58,    58,    59,    60,    60,    61,    62,
      62,    63,    63,    64,    64,    65,    65,    66,    67,    67,
      68,    69,    69,    70,    70,    70,    70,    70,    70,    70,
      70,    70,    70,    70,    71,    71,    72,    72,    73,    73,
      73,    73,    73,    73,    73,    74,    74,    75,    76,    77
};

/* YYR2[YYN] -- Number of symbols composing right hand side of rule YYN.  */
static const yytype_uint8 yyr2[] =
{
       0,     2,     0,     0,     3,     1,     1,     1,     1,     1,
       1,     1,     2,     3,     5,     0,     8,     0,     1,     0,
       7,     0,    12,     0,     9,     0,     7,     1,     2,     1,
       2,     0,     9,     1,     2,     8,     1,     2,     2,     1,
       2,     3,     2,     1,     2,     1,     2,     1,     1,     3,
       1,     3,     1,     3,     3,     4,     6,     6,     6,     6,
       6,     5,     5,     5,     1,     1,     1,     1,     1,     1,
       2,     1,     2,     1,     1,     1,     1,     1,     1,     1
};

/* YYDEFACT[STATE-NAME] -- Default rule to reduce with in state
   STATE-NUM when YYTABLE doesn't specify something else to do.  Zero
   means the default is an error.  */
static const yytype_uint8 yydefact[] =
{
       2,     3,     1,     0,     0,     0,     0,     0,     0,     0,
       0,     4,     8,     5,     6,     7,     9,    10,    11,    78,
       0,     0,     0,     0,    79,     0,    68,    69,    71,    73,
      74,     0,     0,    12,     0,    66,    67,     0,     0,     0,
      19,     0,    15,    13,    70,    72,     0,     0,     0,     0,
      23,    25,    76,     0,    75,     0,     0,     0,     0,     0,
      54,     0,    53,     0,     0,     0,     0,     0,    14,     0,
      45,    47,     0,    17,    48,    50,    52,     0,     0,     0,
       0,     0,     0,     0,     0,    55,     0,     0,    29,    27,
       0,     0,    46,     0,    18,     0,     0,     0,    63,     0,
      62,     0,     0,    61,     0,     0,     0,    30,     0,    28,
      20,     0,    49,     0,    51,    57,    60,    59,    56,    58,
      31,     0,    26,    21,    16,     0,    77,     0,     0,    65,
       0,    33,     0,    64,    24,     0,     0,     0,    36,     0,
      39,     0,    34,     0,     0,    42,     0,    37,     0,    40,
      38,    43,     0,     0,    41,    22,    44,     0,     0,    32,
       0,     0,     0,    35
};

/* YYDEFGOTO[NTERM-NUM].  */
static const yytype_int16 yydefgoto[] =
{
      -1,     1,     3,    11,    12,    13,    14,    57,    95,    15,
      55,    16,   128,    17,    66,    18,    67,    90,    87,    88,
     125,   130,   131,   137,   138,   139,   140,   150,    69,    70,
      73,    74,    75,    71,   132,    34,    35,    53,   127,    76,
      36
};

/* YYPACT[STATE-NUM] -- Index in YYTABLE of the portion describing
   STATE-NUM.  */
#define YYPACT_NINF -87
static const yytype_int16 yypact[] =
{
     -87,    13,   -87,   139,    28,    28,    28,    28,    97,    28,
      28,   -87,   -87,   -87,   -87,   -87,   -87,   -87,   -87,   -87,
      26,    37,    20,    51,   -87,   102,    29,   -87,   -87,   -87,
     -87,    68,    78,   -87,     8,   -87,   -87,    58,    59,    64,
     -87,    70,   -87,   -87,   -87,   -87,    47,    -9,    21,    98,
     -87,   -87,   -87,    81,   -87,   102,   127,    28,    64,    15,
     -87,    17,   -87,    64,    19,    82,    90,   111,   -87,    22,
     -87,   -87,   119,    99,   -87,   -87,   104,    92,   113,   115,
     128,   116,   121,   129,   122,   -87,    28,    46,   -87,   -87,
      14,   131,   -87,   130,    28,   132,    64,   136,   -87,   137,
     -87,   138,   140,   -87,   141,   142,   133,   -87,   144,   -87,
     -87,   145,   -87,   147,   -87,   -87,   -87,   -87,   -87,   -87,
     -87,   160,   -87,   -87,   -87,   120,   -87,   148,    73,   -87,
      45,   -87,    28,   -87,   -87,    64,   143,    49,   -87,    75,
     -87,   146,   -87,   149,   150,   -87,   151,   -87,   152,   -87,
     -87,   -87,   160,   120,   -87,   -87,   -87,   154,   153,   -87,
     156,   160,   157,   -87
};

/* YYPGOTO[NTERM-NUM].  */
static const yytype_int8 yypgoto[] =
{
     -87,   -87,   -87,   -87,   -87,   -87,   -87,   -87,   -87,   -87,
     -87,   -87,   -87,   -38,   -87,   -87,   -87,   -87,   -87,    80,
     -87,   -87,    54,   -87,    38,   -87,    48,   -87,   -87,   117,
     -87,    91,   -87,    -8,    35,   -51,   -87,   -49,   -86,    -3,
     -31
};

/* YYTABLE[YYPACT[STATE-NUM]].  What to do in state STATE-NUM.  If
   positive, shift that token.  If negative, reduce the rule which
   number is the opposite.  If zero, do what YYDEFACT says.
   If YYTABLE_NINF, syntax error.  */
#define YYTABLE_NINF -1
static const yytype_uint8 yytable[] =
{
      33,    20,    21,    22,    23,    72,    37,    38,    54,    77,
      79,    48,    81,     2,    82,    84,    60,    43,    24,    52,
      24,    52,    24,    52,     9,    24,    61,    54,    54,    89,
      54,    19,    54,    54,    26,    27,    28,    29,    30,    41,
      49,   108,    44,    45,    31,    32,    62,   114,    24,    91,
      39,    78,   109,    80,    63,    83,    64,    26,    27,    28,
      29,    30,   129,    40,    86,    54,   157,    24,    52,   135,
     136,    46,   141,   106,   133,   162,   146,    42,    24,   133,
      58,    47,    59,   105,    50,    51,   144,    26,    27,    28,
      29,    30,   148,   135,   136,   135,   136,    31,    32,    56,
      24,    65,   133,    25,    54,    24,    68,    85,    86,    26,
      27,    28,    29,    30,    26,    27,    28,    29,    30,    31,
      32,     9,    93,    24,    31,    32,    97,    94,    96,   143,
      24,   151,    26,    27,    28,    29,    30,   129,    98,    26,
      27,    28,    29,    30,     4,     5,     6,     7,     8,     9,
      10,    99,   101,   100,   103,   102,   110,   121,   104,   113,
     111,   115,   116,   117,   126,   118,   119,   107,   120,   122,
     152,   123,   124,   134,   145,   147,   155,   156,   153,   159,
     161,   154,   163,   160,   142,   112,    92,   149,   158
};

static const yytype_uint8 yycheck[] =
{
       8,     4,     5,     6,     7,    56,     9,    10,    39,    58,
      59,     3,    61,     0,    63,    64,    25,    25,     3,     4,
       3,     4,     3,     4,    10,     3,    35,    58,    59,    67,
      61,     3,    63,    64,    12,    13,    14,    15,    16,    19,
      32,    27,    13,    14,    22,    23,    25,    96,     3,    27,
      24,    36,    90,    36,    33,    36,    35,    12,    13,    14,
      15,    16,    17,    26,    18,    96,   152,     3,     4,    20,
      21,     3,    27,    27,   125,   161,    27,    26,     3,   130,
      33,     3,    35,    86,    26,    26,   135,    12,    13,    14,
      15,    16,    17,    20,    21,    20,    21,    22,    23,    29,
       3,     3,   153,     6,   135,     3,    25,    25,    18,    12,
      13,    14,    15,    16,    12,    13,    14,    15,    16,    22,
      23,    10,     3,     3,    22,    23,    34,    28,    24,   132,
       3,   139,    12,    13,    14,    15,    16,    17,    25,    12,
      13,    14,    15,    16,     5,     6,     7,     8,     9,    10,
      11,    36,    36,    25,    25,    34,    25,    24,    36,    27,
      30,    25,    25,    25,     4,    25,    25,    87,    26,    25,
      24,    26,    25,    25,    31,   137,    25,    25,    29,    25,
      24,    31,    25,    30,   130,    94,    69,   139,   153
};

/* YYSTOS[STATE-NUM] -- The (internal number of the) accessing
   symbol of state STATE-NUM.  */
static const yytype_uint8 yystos[] =
{
       0,    38,     0,    39,     5,     6,     7,     8,     9,    10,
      11,    40,    41,    42,    43,    46,    48,    50,    52,     3,
      76,    76,    76,    76,     3,     6,    12,    13,    14,    15,
      16,    22,    23,    70,    72,    73,    77,    76,    76,    24,
      26,    19,    26,    70,    13,    14,     3,     3,     3,    32,
      26,    26,     4,    74,    77,    47,    29,    44,    33,    35,
      25,    35,    25,    33,    35,     3,    51,    53,    25,    65,
      66,    70,    72,    67,    68,    69,    76,    74,    36,    74,
      36,    74,    74,    36,    74,    25,    18,    55,    56,    50,
      54,    27,    66,     3,    28,    45,    24,    34,    25,    36,
      25,    36,    34,    25,    36,    76,    27,    56,    27,    50,
      25,    30,    68,    27,    74,    25,    25,    25,    25,    25,
      26,    24,    25,    26,    25,    57,     4,    75,    49,    17,
      58,    59,    71,    72,    25,    20,    21,    60,    61,    62,
      63,    27,    59,    76,    74,    31,    27,    61,    17,    63,
      64,    70,    24,    29,    31,    25,    25,    75,    71,    25,
      30,    24,    75,    25
};

#define yyerrok		(yyerrstatus = 0)
#define yyclearin	(yychar = YYEMPTY)
#define YYEMPTY		(-2)
#define YYEOF		0

#define YYACCEPT	goto yyacceptlab
#define YYABORT		goto yyabortlab
#define YYERROR		goto yyerrorlab


/* Like YYERROR except do call yyerror.  This remains here temporarily
   to ease the transition to the new meaning of YYERROR, for GCC.
   Once GCC version 2 has supplanted version 1, this can go.  */

#define YYFAIL		goto yyerrlab

#define YYRECOVERING()  (!!yyerrstatus)

#define YYBACKUP(Token, Value)					\
do								\
  if (yychar == YYEMPTY && yylen == 1)				\
    {								\
      yychar = (Token);						\
      yylval = (Value);						\
      yytoken = YYTRANSLATE (yychar);				\
      YYPOPSTACK (1);						\
      goto yybackup;						\
    }								\
  else								\
    {								\
      yyerror (YY_("syntax error: cannot back up")); \
      YYERROR;							\
    }								\
while (YYID (0))


#define YYTERROR	1
#define YYERRCODE	256


/* YYLLOC_DEFAULT -- Set CURRENT to span from RHS[1] to RHS[N].
   If N is 0, then set CURRENT to the empty location which ends
   the previous symbol: RHS[0] (always defined).  */

#define YYRHSLOC(Rhs, K) ((Rhs)[K])
#ifndef YYLLOC_DEFAULT
# define YYLLOC_DEFAULT(Current, Rhs, N)				\
    do									\
      if (YYID (N))                                                    \
	{								\
	  (Current).first_line   = YYRHSLOC (Rhs, 1).first_line;	\
	  (Current).first_column = YYRHSLOC (Rhs, 1).first_column;	\
	  (Current).last_line    = YYRHSLOC (Rhs, N).last_line;		\
	  (Current).last_column  = YYRHSLOC (Rhs, N).last_column;	\
	}								\
      else								\
	{								\
	  (Current).first_line   = (Current).last_line   =		\
	    YYRHSLOC (Rhs, 0).last_line;				\
	  (Current).first_column = (Current).last_column =		\
	    YYRHSLOC (Rhs, 0).last_column;				\
	}								\
    while (YYID (0))
#endif


/* YY_LOCATION_PRINT -- Print the location on the stream.
   This macro was not mandated originally: define only if we know
   we won't break user code: when these are the locations we know.  */

#ifndef YY_LOCATION_PRINT
# if YYLTYPE_IS_TRIVIAL
#  define YY_LOCATION_PRINT(File, Loc)			\
     fprintf (File, "%d.%d-%d.%d",			\
	      (Loc).first_line, (Loc).first_column,	\
	      (Loc).last_line,  (Loc).last_column)
# else
#  define YY_LOCATION_PRINT(File, Loc) ((void) 0)
# endif
#endif


/* YYLEX -- calling `yylex' with the right arguments.  */

#ifdef YYLEX_PARAM
# define YYLEX yylex (YYLEX_PARAM)
#else
# define YYLEX yylex ()
#endif

/* Enable debugging if requested.  */
#if YYDEBUG

# ifndef YYFPRINTF
#  include <stdio.h> /* INFRINGES ON USER NAME SPACE */
#  define YYFPRINTF fprintf
# endif

# define YYDPRINTF(Args)			\
do {						\
  if (yydebug)					\
    YYFPRINTF Args;				\
} while (YYID (0))

# define YY_SYMBOL_PRINT(Title, Type, Value, Location)			  \
do {									  \
  if (yydebug)								  \
    {									  \
      YYFPRINTF (stderr, "%s ", Title);					  \
      yy_symbol_print (stderr,						  \
		  Type, Value); \
      YYFPRINTF (stderr, "\n");						  \
    }									  \
} while (YYID (0))


/*--------------------------------.
| Print this symbol on YYOUTPUT.  |
`--------------------------------*/

/*ARGSUSED*/
#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
static void
yy_symbol_value_print (FILE *yyoutput, int yytype, YYSTYPE const * const yyvaluep)
#else
static void
yy_symbol_value_print (yyoutput, yytype, yyvaluep)
    FILE *yyoutput;
    int yytype;
    YYSTYPE const * const yyvaluep;
#endif
{
  if (!yyvaluep)
    return;
# ifdef YYPRINT
  if (yytype < YYNTOKENS)
    YYPRINT (yyoutput, yytoknum[yytype], *yyvaluep);
# else
  YYUSE (yyoutput);
# endif
  switch (yytype)
    {
      default:
	break;
    }
}


/*--------------------------------.
| Print this symbol on YYOUTPUT.  |
`--------------------------------*/

#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
static void
yy_symbol_print (FILE *yyoutput, int yytype, YYSTYPE const * const yyvaluep)
#else
static void
yy_symbol_print (yyoutput, yytype, yyvaluep)
    FILE *yyoutput;
    int yytype;
    YYSTYPE const * const yyvaluep;
#endif
{
  if (yytype < YYNTOKENS)
    YYFPRINTF (yyoutput, "token %s (", yytname[yytype]);
  else
    YYFPRINTF (yyoutput, "nterm %s (", yytname[yytype]);

  yy_symbol_value_print (yyoutput, yytype, yyvaluep);
  YYFPRINTF (yyoutput, ")");
}

/*------------------------------------------------------------------.
| yy_stack_print -- Print the state stack from its BOTTOM up to its |
| TOP (included).                                                   |
`------------------------------------------------------------------*/

#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
static void
yy_stack_print (yytype_int16 *bottom, yytype_int16 *top)
#else
static void
yy_stack_print (bottom, top)
    yytype_int16 *bottom;
    yytype_int16 *top;
#endif
{
  YYFPRINTF (stderr, "Stack now");
  for (; bottom <= top; ++bottom)
    YYFPRINTF (stderr, " %d", *bottom);
  YYFPRINTF (stderr, "\n");
}

# define YY_STACK_PRINT(Bottom, Top)				\
do {								\
  if (yydebug)							\
    yy_stack_print ((Bottom), (Top));				\
} while (YYID (0))


/*------------------------------------------------.
| Report that the YYRULE is going to be reduced.  |
`------------------------------------------------*/

#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
static void
yy_reduce_print (YYSTYPE *yyvsp, int yyrule)
#else
static void
yy_reduce_print (yyvsp, yyrule)
    YYSTYPE *yyvsp;
    int yyrule;
#endif
{
  int yynrhs = yyr2[yyrule];
  int yyi;
  unsigned long int yylno = yyrline[yyrule];
  YYFPRINTF (stderr, "Reducing stack by rule %d (line %lu):\n",
	     yyrule - 1, yylno);
  /* The symbols being reduced.  */
  for (yyi = 0; yyi < yynrhs; yyi++)
    {
      fprintf (stderr, "   $%d = ", yyi + 1);
      yy_symbol_print (stderr, yyrhs[yyprhs[yyrule] + yyi],
		       &(yyvsp[(yyi + 1) - (yynrhs)])
		       		       );
      fprintf (stderr, "\n");
    }
}

# define YY_REDUCE_PRINT(Rule)		\
do {					\
  if (yydebug)				\
    yy_reduce_print (yyvsp, Rule); \
} while (YYID (0))

/* Nonzero means print parse trace.  It is left uninitialized so that
   multiple parsers can coexist.  */
int yydebug;
#else /* !YYDEBUG */
# define YYDPRINTF(Args)
# define YY_SYMBOL_PRINT(Title, Type, Value, Location)
# define YY_STACK_PRINT(Bottom, Top)
# define YY_REDUCE_PRINT(Rule)
#endif /* !YYDEBUG */


/* YYINITDEPTH -- initial size of the parser's stacks.  */
#ifndef	YYINITDEPTH
# define YYINITDEPTH 200
#endif

/* YYMAXDEPTH -- maximum size the stacks can grow to (effective only
   if the built-in stack extension method is used).

   Do not make this value too large; the results are undefined if
   YYSTACK_ALLOC_MAXIMUM < YYSTACK_BYTES (YYMAXDEPTH)
   evaluated with infinite-precision integer arithmetic.  */

#ifndef YYMAXDEPTH
# define YYMAXDEPTH 10000
#endif



#if YYERROR_VERBOSE

# ifndef yystrlen
#  if defined __GLIBC__ && defined _STRING_H
#   define yystrlen strlen
#  else
/* Return the length of YYSTR.  */
#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
static YYSIZE_T
yystrlen (const char *yystr)
#else
static YYSIZE_T
yystrlen (yystr)
    const char *yystr;
#endif
{
  YYSIZE_T yylen;
  for (yylen = 0; yystr[yylen]; yylen++)
    continue;
  return yylen;
}
#  endif
# endif

# ifndef yystpcpy
#  if defined __GLIBC__ && defined _STRING_H && defined _GNU_SOURCE
#   define yystpcpy stpcpy
#  else
/* Copy YYSRC to YYDEST, returning the address of the terminating '\0' in
   YYDEST.  */
#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
static char *
yystpcpy (char *yydest, const char *yysrc)
#else
static char *
yystpcpy (yydest, yysrc)
    char *yydest;
    const char *yysrc;
#endif
{
  char *yyd = yydest;
  const char *yys = yysrc;

  while ((*yyd++ = *yys++) != '\0')
    continue;

  return yyd - 1;
}
#  endif
# endif

# ifndef yytnamerr
/* Copy to YYRES the contents of YYSTR after stripping away unnecessary
   quotes and backslashes, so that it's suitable for yyerror.  The
   heuristic is that double-quoting is unnecessary unless the string
   contains an apostrophe, a comma, or backslash (other than
   backslash-backslash).  YYSTR is taken from yytname.  If YYRES is
   null, do not copy; instead, return the length of what the result
   would have been.  */
static YYSIZE_T
yytnamerr (char *yyres, const char *yystr)
{
  if (*yystr == '"')
    {
      YYSIZE_T yyn = 0;
      char const *yyp = yystr;

      for (;;)
	switch (*++yyp)
	  {
	  case '\'':
	  case ',':
	    goto do_not_strip_quotes;

	  case '\\':
	    if (*++yyp != '\\')
	      goto do_not_strip_quotes;
	    /* Fall through.  */
	  default:
	    if (yyres)
	      yyres[yyn] = *yyp;
	    yyn++;
	    break;

	  case '"':
	    if (yyres)
	      yyres[yyn] = '\0';
	    return yyn;
	  }
    do_not_strip_quotes: ;
    }

  if (! yyres)
    return yystrlen (yystr);

  return yystpcpy (yyres, yystr) - yyres;
}
# endif

/* Copy into YYRESULT an error message about the unexpected token
   YYCHAR while in state YYSTATE.  Return the number of bytes copied,
   including the terminating null byte.  If YYRESULT is null, do not
   copy anything; just return the number of bytes that would be
   copied.  As a special case, return 0 if an ordinary "syntax error"
   message will do.  Return YYSIZE_MAXIMUM if overflow occurs during
   size calculation.  */
static YYSIZE_T
yysyntax_error (char *yyresult, int yystate, int yychar)
{
  int yyn = yypact[yystate];

  if (! (YYPACT_NINF < yyn && yyn <= YYLAST))
    return 0;
  else
    {
      int yytype = YYTRANSLATE (yychar);
      YYSIZE_T yysize0 = yytnamerr (0, yytname[yytype]);
      YYSIZE_T yysize = yysize0;
      YYSIZE_T yysize1;
      int yysize_overflow = 0;
      enum { YYERROR_VERBOSE_ARGS_MAXIMUM = 5 };
      char const *yyarg[YYERROR_VERBOSE_ARGS_MAXIMUM];
      int yyx;

# if 0
      /* This is so xgettext sees the translatable formats that are
	 constructed on the fly.  */
      YY_("syntax error, unexpected %s");
      YY_("syntax error, unexpected %s, expecting %s");
      YY_("syntax error, unexpected %s, expecting %s or %s");
      YY_("syntax error, unexpected %s, expecting %s or %s or %s");
      YY_("syntax error, unexpected %s, expecting %s or %s or %s or %s");
# endif
      char *yyfmt;
      char const *yyf;
      static char const yyunexpected[] = "syntax error, unexpected %s";
      static char const yyexpecting[] = ", expecting %s";
      static char const yyor[] = " or %s";
      char yyformat[sizeof yyunexpected
		    + sizeof yyexpecting - 1
		    + ((YYERROR_VERBOSE_ARGS_MAXIMUM - 2)
		       * (sizeof yyor - 1))];
      char const *yyprefix = yyexpecting;

      /* Start YYX at -YYN if negative to avoid negative indexes in
	 YYCHECK.  */
      int yyxbegin = yyn < 0 ? -yyn : 0;

      /* Stay within bounds of both yycheck and yytname.  */
      int yychecklim = YYLAST - yyn + 1;
      int yyxend = yychecklim < YYNTOKENS ? yychecklim : YYNTOKENS;
      int yycount = 1;

      yyarg[0] = yytname[yytype];
      yyfmt = yystpcpy (yyformat, yyunexpected);

      for (yyx = yyxbegin; yyx < yyxend; ++yyx)
	if (yycheck[yyx + yyn] == yyx && yyx != YYTERROR)
	  {
	    if (yycount == YYERROR_VERBOSE_ARGS_MAXIMUM)
	      {
		yycount = 1;
		yysize = yysize0;
		yyformat[sizeof yyunexpected - 1] = '\0';
		break;
	      }
	    yyarg[yycount++] = yytname[yyx];
	    yysize1 = yysize + yytnamerr (0, yytname[yyx]);
	    yysize_overflow |= (yysize1 < yysize);
	    yysize = yysize1;
	    yyfmt = yystpcpy (yyfmt, yyprefix);
	    yyprefix = yyor;
	  }

      yyf = YY_(yyformat);
      yysize1 = yysize + yystrlen (yyf);
      yysize_overflow |= (yysize1 < yysize);
      yysize = yysize1;

      if (yysize_overflow)
	return YYSIZE_MAXIMUM;

      if (yyresult)
	{
	  /* Avoid sprintf, as that infringes on the user's name space.
	     Don't have undefined behavior even if the translation
	     produced a string with the wrong number of "%s"s.  */
	  char *yyp = yyresult;
	  int yyi = 0;
	  while ((*yyp = *yyf) != '\0')
	    {
	      if (*yyp == '%' && yyf[1] == 's' && yyi < yycount)
		{
		  yyp += yytnamerr (yyp, yyarg[yyi++]);
		  yyf += 2;
		}
	      else
		{
		  yyp++;
		  yyf++;
		}
	    }
	}
      return yysize;
    }
}
#endif /* YYERROR_VERBOSE */


/*-----------------------------------------------.
| Release the memory associated to this symbol.  |
`-----------------------------------------------*/

/*ARGSUSED*/
#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
static void
yydestruct (const char *yymsg, int yytype, YYSTYPE *yyvaluep)
#else
static void
yydestruct (yymsg, yytype, yyvaluep)
    const char *yymsg;
    int yytype;
    YYSTYPE *yyvaluep;
#endif
{
  YYUSE (yyvaluep);

  if (!yymsg)
    yymsg = "Deleting";
  YY_SYMBOL_PRINT (yymsg, yytype, yyvaluep, yylocationp);

  switch (yytype)
    {

      default:
	break;
    }
}


/* Prevent warnings from -Wmissing-prototypes.  */

#ifdef YYPARSE_PARAM
#if defined __STDC__ || defined __cplusplus
int yyparse (void *YYPARSE_PARAM);
#else
int yyparse ();
#endif
#else /* ! YYPARSE_PARAM */
#if defined __STDC__ || defined __cplusplus
int yyparse (void);
#else
int yyparse ();
#endif
#endif /* ! YYPARSE_PARAM */



/* The look-ahead symbol.  */
int yychar;

/* The semantic value of the look-ahead symbol.  */
YYSTYPE yylval;

/* Number of syntax errors so far.  */
int yynerrs;



/*----------.
| yyparse.  |
`----------*/

#ifdef YYPARSE_PARAM
#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
int
yyparse (void *YYPARSE_PARAM)
#else
int
yyparse (YYPARSE_PARAM)
    void *YYPARSE_PARAM;
#endif
#else /* ! YYPARSE_PARAM */
#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
int
yyparse (void)
#else
int
yyparse ()

#endif
#endif
{
  
  int yystate;
  int yyn;
  int yyresult;
  /* Number of tokens to shift before error messages enabled.  */
  int yyerrstatus;
  /* Look-ahead token as an internal (translated) token number.  */
  int yytoken = 0;
#if YYERROR_VERBOSE
  /* Buffer for error messages, and its allocated size.  */
  char yymsgbuf[128];
  char *yymsg = yymsgbuf;
  YYSIZE_T yymsg_alloc = sizeof yymsgbuf;
#endif

  /* Three stacks and their tools:
     `yyss': related to states,
     `yyvs': related to semantic values,
     `yyls': related to locations.

     Refer to the stacks thru separate pointers, to allow yyoverflow
     to reallocate them elsewhere.  */

  /* The state stack.  */
  yytype_int16 yyssa[YYINITDEPTH];
  yytype_int16 *yyss = yyssa;
  yytype_int16 *yyssp;

  /* The semantic value stack.  */
  YYSTYPE yyvsa[YYINITDEPTH];
  YYSTYPE *yyvs = yyvsa;
  YYSTYPE *yyvsp;



#define YYPOPSTACK(N)   (yyvsp -= (N), yyssp -= (N))

  YYSIZE_T yystacksize = YYINITDEPTH;

  /* The variables used to return semantic value and location from the
     action routines.  */
  YYSTYPE yyval;


  /* The number of symbols on the RHS of the reduced rule.
     Keep to zero when no symbol should be popped.  */
  int yylen = 0;

  YYDPRINTF ((stderr, "Starting parse\n"));

  yystate = 0;
  yyerrstatus = 0;
  yynerrs = 0;
  yychar = YYEMPTY;		/* Cause a token to be read.  */

  /* Initialize stack pointers.
     Waste one element of value and location stack
     so that they stay on the same level as the state stack.
     The wasted elements are never initialized.  */

  yyssp = yyss;
  yyvsp = yyvs;

  goto yysetstate;

/*------------------------------------------------------------.
| yynewstate -- Push a new state, which is found in yystate.  |
`------------------------------------------------------------*/
 yynewstate:
  /* In all cases, when you get here, the value and location stacks
     have just been pushed.  So pushing a state here evens the stacks.  */
  yyssp++;

 yysetstate:
  *yyssp = yystate;

  if (yyss + yystacksize - 1 <= yyssp)
    {
      /* Get the current used size of the three stacks, in elements.  */
      YYSIZE_T yysize = yyssp - yyss + 1;

#ifdef yyoverflow
      {
	/* Give user a chance to reallocate the stack.  Use copies of
	   these so that the &'s don't force the real ones into
	   memory.  */
	YYSTYPE *yyvs1 = yyvs;
	yytype_int16 *yyss1 = yyss;


	/* Each stack pointer address is followed by the size of the
	   data in use in that stack, in bytes.  This used to be a
	   conditional around just the two extra args, but that might
	   be undefined if yyoverflow is a macro.  */
	yyoverflow (YY_("memory exhausted"),
		    &yyss1, yysize * sizeof (*yyssp),
		    &yyvs1, yysize * sizeof (*yyvsp),

		    &yystacksize);

	yyss = yyss1;
	yyvs = yyvs1;
      }
#else /* no yyoverflow */
# ifndef YYSTACK_RELOCATE
      goto yyexhaustedlab;
# else
      /* Extend the stack our own way.  */
      if (YYMAXDEPTH <= yystacksize)
	goto yyexhaustedlab;
      yystacksize *= 2;
      if (YYMAXDEPTH < yystacksize)
	yystacksize = YYMAXDEPTH;

      {
	yytype_int16 *yyss1 = yyss;
	struct yyalloc *yyptr =
	  (struct yyalloc *) YYSTACK_ALLOC (YYSTACK_BYTES (yystacksize));
	if (! yyptr)
	  goto yyexhaustedlab;
	YYSTACK_RELOCATE (yyss);
	YYSTACK_RELOCATE (yyvs);

#  undef YYSTACK_RELOCATE
	if (yyss1 != yyssa)
	  YYSTACK_FREE (yyss1);
      }
# endif
#endif /* no yyoverflow */

      yyssp = yyss + yysize - 1;
      yyvsp = yyvs + yysize - 1;


      YYDPRINTF ((stderr, "Stack size increased to %lu\n",
		  (unsigned long int) yystacksize));

      if (yyss + yystacksize - 1 <= yyssp)
	YYABORT;
    }

  YYDPRINTF ((stderr, "Entering state %d\n", yystate));

  goto yybackup;

/*-----------.
| yybackup.  |
`-----------*/
yybackup:

  /* Do appropriate processing given the current state.  Read a
     look-ahead token if we need one and don't already have one.  */

  /* First try to decide what to do without reference to look-ahead token.  */
  yyn = yypact[yystate];
  if (yyn == YYPACT_NINF)
    goto yydefault;

  /* Not known => get a look-ahead token if don't already have one.  */

  /* YYCHAR is either YYEMPTY or YYEOF or a valid look-ahead symbol.  */
  if (yychar == YYEMPTY)
    {
      YYDPRINTF ((stderr, "Reading a token: "));
      yychar = YYLEX;
    }

  if (yychar <= YYEOF)
    {
      yychar = yytoken = YYEOF;
      YYDPRINTF ((stderr, "Now at end of input.\n"));
    }
  else
    {
      yytoken = YYTRANSLATE (yychar);
      YY_SYMBOL_PRINT ("Next token is", yytoken, &yylval, &yylloc);
    }

  /* If the proper action on seeing token YYTOKEN is to reduce or to
     detect an error, take that action.  */
  yyn += yytoken;
  if (yyn < 0 || YYLAST < yyn || yycheck[yyn] != yytoken)
    goto yydefault;
  yyn = yytable[yyn];
  if (yyn <= 0)
    {
      if (yyn == 0 || yyn == YYTABLE_NINF)
	goto yyerrlab;
      yyn = -yyn;
      goto yyreduce;
    }

  if (yyn == YYFINAL)
    YYACCEPT;

  /* Count tokens shifted since error; after three, turn off error
     status.  */
  if (yyerrstatus)
    yyerrstatus--;

  /* Shift the look-ahead token.  */
  YY_SYMBOL_PRINT ("Shifting", yytoken, &yylval, &yylloc);

  /* Discard the shifted token unless it is eof.  */
  if (yychar != YYEOF)
    yychar = YYEMPTY;

  yystate = yyn;
  *++yyvsp = yylval;

  goto yynewstate;


/*-----------------------------------------------------------.
| yydefault -- do the default action for the current state.  |
`-----------------------------------------------------------*/
yydefault:
  yyn = yydefact[yystate];
  if (yyn == 0)
    goto yyerrlab;
  goto yyreduce;


/*-----------------------------.
| yyreduce -- Do a reduction.  |
`-----------------------------*/
yyreduce:
  /* yyn is the number of a rule to reduce with.  */
  yylen = yyr2[yyn];

  /* If YYLEN is nonzero, implement the default value of the action:
     `$$ = $1'.

     Otherwise, the following line sets YYVAL to garbage.
     This behavior is undocumented and Bison
     users should not rely upon it.  Assigning to YYVAL
     unconditionally makes the parser a bit smaller, and it avoids a
     GCC warning that YYVAL may be used uninitialized.  */
  yyval = yyvsp[1-yylen];


  YY_REDUCE_PRINT (yyn);
  switch (yyn)
    {
        case 2:
#line 66 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { checkliterals (); }
    break;

  case 3:
#line 67 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { checkliterals (); }
    break;

  case 4:
#line 67 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { checkliterals (); }
    break;

  case 12:
#line 80 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {
	  rpc_sym *s = &symlist.push_back ();
	  s->settype (rpc_sym::TYPEDEF);
	  *s->stypedef = (yyvsp[(2) - (2)].decl);
	  s->stypedef->id = getnewid (s->stypedef->id);
	}
    break;

  case 13:
#line 87 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {
	  rpc_sym *s = &symlist.push_back ();
	  s->settype (rpc_sym::TYPEDEF);
	  *s->stypedef = (yyvsp[(3) - (3)].decl);
	  s->stypedef->type = strbuf ("struct ") << (yyvsp[(3) - (3)].decl).type;
	  s->stypedef->id = getnewid (s->stypedef->id);
	}
    break;

  case 14:
#line 97 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {
	  rpc_sym *s = &symlist.push_back ();
	  s->settype (rpc_sym::CONST);
	  s->sconst->id = (yyvsp[(2) - (5)].str);
	  s->sconst->val = (yyvsp[(4) - (5)].str);
	}
    break;

  case 15:
#line 106 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {
	  rpc_sym *s = &symlist.push_back ();
	  s->settype (rpc_sym::ENUM);
	  s->senum->id = (yyvsp[(2) - (3)].str);
	}
    break;

  case 18:
#line 115 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { yywarn ("comma not allowed at end of enum"); }
    break;

  case 19:
#line 119 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {
	  rpc_sym *s = &symlist.push_back ();
	  s->settype (rpc_sym::STRUCT);
	  s->sstruct->id = (yyvsp[(2) - (3)].str);
	}
    break;

  case 21:
#line 128 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {
	  rpc_sym *s = &symlist.push_back ();
	  s->settype (rpc_sym::UNION);
	  s->sunion->id = (yyvsp[(2) - (8)].str);
	  s->sunion->tagtype = (yyvsp[(5) - (8)].str);
	  s->sunion->tagid = (yyvsp[(6) - (8)].str);
	}
    break;

  case 23:
#line 139 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {
	  rpc_program *s = get_prog (true);
	  s->id = (yyvsp[(2) - (3)].str);
	}
    break;

  case 24:
#line 144 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {
	  rpc_program *s = get_prog (false);
	  s->val = (yyvsp[(8) - (9)].num);
	  qsort (s->vers.base (), s->vers.size (), 
	         sizeof (rpc_vers), vers_compare);
	}
    break;

  case 25:
#line 153 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {
	  rpc_sym *s = &symlist.push_back ();
	  s->settype (rpc_sym::NAMESPACE);
	  s->snamespace->id = (yyvsp[(2) - (3)].str);

        }
    break;

  case 31:
#line 169 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {
          rpc_program *p = get_prog (false);
	  rpc_vers *rv = &p->vers.push_back ();
	  rv->id = (yyvsp[(2) - (3)].str);
	}
    break;

  case 32:
#line 175 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {
          rpc_program *p = get_prog (false);
	  rpc_vers *rv = &p->vers.back ();
	  rv->val = (yyvsp[(8) - (9)].num);
	  qsort (rv->procs.base (), rv->procs.size (),
		 sizeof (rpc_proc), proc_compare);
	}
    break;

  case 35:
#line 188 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {
          rpc_program *p = get_prog (false);
	  rpc_vers *rv = &p->vers.back ();
	  rpc_proc *rp = &rv->procs.push_back ();
	  rp->id = (yyvsp[(2) - (8)].str);
	  rp->val = (yyvsp[(7) - (8)].num);
	  rp->arg = (yyvsp[(4) - (8)].str);
	  rp->res = (yyvsp[(1) - (8)].str);
	}
    break;

  case 41:
#line 209 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {
	  rpc_sym *s = &symlist.back ();
	  rpc_utag *ut = &s->sunion->cases.push_back ();
	  ut->tagvalid = false;
	  ut->swval = (yyvsp[(2) - (3)].str);
	}
    break;

  case 42:
#line 216 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {
	  rpc_sym *s = &symlist.back ();
	  rpc_utag *ut = &s->sunion->cases.push_back ();
	  ut->tagvalid = false;
	}
    break;

  case 43:
#line 224 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {
	  rpc_sym *s = &symlist.back ();
	  rpc_utag *ut = &s->sunion->cases.back ();
	  ut->tagvalid = true;
	  ut->tag = (yyvsp[(1) - (1)].decl);
	}
    break;

  case 44:
#line 231 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {
	  rpc_sym *s = &symlist.back ();
	  rpc_utag *ut = &s->sunion->cases.back ();
	  ut->tagvalid = true;
	  ut->tag.type = "void";
	  ut->tag.qual = rpc_decl::SCALAR;
	}
    break;

  case 47:
#line 244 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { symlist.back ().sstruct->decls.push_back ((yyvsp[(1) - (1)].decl)); }
    break;

  case 48:
#line 247 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {}
    break;

  case 49:
#line 248 "/home/max/sfslite/1.2/rpcc/parse.yy"
    {}
    break;

  case 50:
#line 252 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { symlist.back ().senum->tags.push_back ((yyvsp[(1) - (1)].cnst)); }
    break;

  case 51:
#line 255 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.cnst).id = (yyvsp[(1) - (3)].str); (yyval.cnst).val = (yyvsp[(3) - (3)].str); }
    break;

  case 52:
#line 256 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.cnst).id = (yyvsp[(1) - (1)].str); }
    break;

  case 53:
#line 260 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.decl).id = (yyvsp[(2) - (3)].str); (yyval.decl).type = (yyvsp[(1) - (3)].str); (yyval.decl).qual = rpc_decl::SCALAR; }
    break;

  case 54:
#line 262 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.decl).id = (yyvsp[(2) - (3)].str); (yyval.decl).type = (yyvsp[(1) - (3)].str); (yyval.decl).qual = rpc_decl::VEC;
	   (yyval.decl).bound = "RPC_INFINITY";
	   yywarn ("strings require variable-length array declarations");
	 }
    break;

  case 55:
#line 267 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.decl).id = (yyvsp[(3) - (4)].str); (yyval.decl).type = (yyvsp[(1) - (4)].str); (yyval.decl).qual = rpc_decl::PTR; }
    break;

  case 56:
#line 269 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.decl).id = (yyvsp[(2) - (6)].str); (yyval.decl).type = (yyvsp[(1) - (6)].str); (yyval.decl).qual = rpc_decl::ARRAY;
	   (yyval.decl).bound = (yyvsp[(4) - (6)].str); }
    break;

  case 57:
#line 272 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.decl).id = (yyvsp[(2) - (6)].str); (yyval.decl).type = (yyvsp[(1) - (6)].str); (yyval.decl).qual = rpc_decl::ARRAY;
	   (yyval.decl).bound = (yyvsp[(4) - (6)].str); }
    break;

  case 58:
#line 275 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.decl).id = (yyvsp[(2) - (6)].str); (yyval.decl).type = (yyvsp[(1) - (6)].str); (yyval.decl).qual = rpc_decl::VEC; (yyval.decl).bound = (yyvsp[(4) - (6)].str); }
    break;

  case 59:
#line 277 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.decl).id = (yyvsp[(2) - (6)].str); (yyval.decl).type = (yyvsp[(1) - (6)].str); (yyval.decl).qual = rpc_decl::VEC; (yyval.decl).bound = (yyvsp[(4) - (6)].str); }
    break;

  case 60:
#line 279 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.decl).id = (yyvsp[(2) - (6)].str); (yyval.decl).type = (yyvsp[(1) - (6)].str); (yyval.decl).qual = rpc_decl::VEC; (yyval.decl).bound = (yyvsp[(4) - (6)].str); }
    break;

  case 61:
#line 281 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.decl).id = (yyvsp[(2) - (5)].str); (yyval.decl).type = (yyvsp[(1) - (5)].str); (yyval.decl).qual = rpc_decl::VEC;
	   (yyval.decl).bound = "RPC_INFINITY"; }
    break;

  case 62:
#line 284 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.decl).id = (yyvsp[(2) - (5)].str); (yyval.decl).type = (yyvsp[(1) - (5)].str); (yyval.decl).qual = rpc_decl::VEC;
	   (yyval.decl).bound = "RPC_INFINITY"; }
    break;

  case 63:
#line 287 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.decl).id = (yyvsp[(2) - (5)].str); (yyval.decl).type = (yyvsp[(1) - (5)].str); (yyval.decl).qual = rpc_decl::VEC;
	   (yyval.decl).bound = "RPC_INFINITY"; }
    break;

  case 65:
#line 291 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.str) = "void"; }
    break;

  case 68:
#line 297 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.str) = "u_int32_t"; }
    break;

  case 69:
#line 298 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.str) = "int32_t"; }
    break;

  case 70:
#line 299 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.str) = "u_int32_t"; }
    break;

  case 71:
#line 300 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.str) = "int64_t"; }
    break;

  case 72:
#line 301 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.str) = "u_int64_t"; }
    break;

  case 73:
#line 302 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.str) = "double"; }
    break;

  case 74:
#line 303 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.str) = "quadruple"; }
    break;

  case 77:
#line 309 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.num) = strtoul ((yyvsp[(1) - (1)].str), NULL, 0); }
    break;

  case 78:
#line 312 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.str) = getnewid ((yyvsp[(1) - (1)].str)); }
    break;

  case 79:
#line 315 "/home/max/sfslite/1.2/rpcc/parse.yy"
    { (yyval.str) = getid ((yyvsp[(1) - (1)].str)); }
    break;


/* Line 1267 of yacc.c.  */
#line 1833 "y.tab.c"
      default: break;
    }
  YY_SYMBOL_PRINT ("-> $$ =", yyr1[yyn], &yyval, &yyloc);

  YYPOPSTACK (yylen);
  yylen = 0;
  YY_STACK_PRINT (yyss, yyssp);

  *++yyvsp = yyval;


  /* Now `shift' the result of the reduction.  Determine what state
     that goes to, based on the state we popped back to and the rule
     number reduced by.  */

  yyn = yyr1[yyn];

  yystate = yypgoto[yyn - YYNTOKENS] + *yyssp;
  if (0 <= yystate && yystate <= YYLAST && yycheck[yystate] == *yyssp)
    yystate = yytable[yystate];
  else
    yystate = yydefgoto[yyn - YYNTOKENS];

  goto yynewstate;


/*------------------------------------.
| yyerrlab -- here on detecting error |
`------------------------------------*/
yyerrlab:
  /* If not already recovering from an error, report this error.  */
  if (!yyerrstatus)
    {
      ++yynerrs;
#if ! YYERROR_VERBOSE
      yyerror (YY_("syntax error"));
#else
      {
	YYSIZE_T yysize = yysyntax_error (0, yystate, yychar);
	if (yymsg_alloc < yysize && yymsg_alloc < YYSTACK_ALLOC_MAXIMUM)
	  {
	    YYSIZE_T yyalloc = 2 * yysize;
	    if (! (yysize <= yyalloc && yyalloc <= YYSTACK_ALLOC_MAXIMUM))
	      yyalloc = YYSTACK_ALLOC_MAXIMUM;
	    if (yymsg != yymsgbuf)
	      YYSTACK_FREE (yymsg);
	    yymsg = (char *) YYSTACK_ALLOC (yyalloc);
	    if (yymsg)
	      yymsg_alloc = yyalloc;
	    else
	      {
		yymsg = yymsgbuf;
		yymsg_alloc = sizeof yymsgbuf;
	      }
	  }

	if (0 < yysize && yysize <= yymsg_alloc)
	  {
	    (void) yysyntax_error (yymsg, yystate, yychar);
	    yyerror (yymsg);
	  }
	else
	  {
	    yyerror (YY_("syntax error"));
	    if (yysize != 0)
	      goto yyexhaustedlab;
	  }
      }
#endif
    }



  if (yyerrstatus == 3)
    {
      /* If just tried and failed to reuse look-ahead token after an
	 error, discard it.  */

      if (yychar <= YYEOF)
	{
	  /* Return failure if at end of input.  */
	  if (yychar == YYEOF)
	    YYABORT;
	}
      else
	{
	  yydestruct ("Error: discarding",
		      yytoken, &yylval);
	  yychar = YYEMPTY;
	}
    }

  /* Else will try to reuse look-ahead token after shifting the error
     token.  */
  goto yyerrlab1;


/*---------------------------------------------------.
| yyerrorlab -- error raised explicitly by YYERROR.  |
`---------------------------------------------------*/
yyerrorlab:

  /* Pacify compilers like GCC when the user code never invokes
     YYERROR and the label yyerrorlab therefore never appears in user
     code.  */
  if (/*CONSTCOND*/ 0)
     goto yyerrorlab;

  /* Do not reclaim the symbols of the rule which action triggered
     this YYERROR.  */
  YYPOPSTACK (yylen);
  yylen = 0;
  YY_STACK_PRINT (yyss, yyssp);
  yystate = *yyssp;
  goto yyerrlab1;


/*-------------------------------------------------------------.
| yyerrlab1 -- common code for both syntax error and YYERROR.  |
`-------------------------------------------------------------*/
yyerrlab1:
  yyerrstatus = 3;	/* Each real token shifted decrements this.  */

  for (;;)
    {
      yyn = yypact[yystate];
      if (yyn != YYPACT_NINF)
	{
	  yyn += YYTERROR;
	  if (0 <= yyn && yyn <= YYLAST && yycheck[yyn] == YYTERROR)
	    {
	      yyn = yytable[yyn];
	      if (0 < yyn)
		break;
	    }
	}

      /* Pop the current state because it cannot handle the error token.  */
      if (yyssp == yyss)
	YYABORT;


      yydestruct ("Error: popping",
		  yystos[yystate], yyvsp);
      YYPOPSTACK (1);
      yystate = *yyssp;
      YY_STACK_PRINT (yyss, yyssp);
    }

  if (yyn == YYFINAL)
    YYACCEPT;

  *++yyvsp = yylval;


  /* Shift the error token.  */
  YY_SYMBOL_PRINT ("Shifting", yystos[yyn], yyvsp, yylsp);

  yystate = yyn;
  goto yynewstate;


/*-------------------------------------.
| yyacceptlab -- YYACCEPT comes here.  |
`-------------------------------------*/
yyacceptlab:
  yyresult = 0;
  goto yyreturn;

/*-----------------------------------.
| yyabortlab -- YYABORT comes here.  |
`-----------------------------------*/
yyabortlab:
  yyresult = 1;
  goto yyreturn;

#ifndef yyoverflow
/*-------------------------------------------------.
| yyexhaustedlab -- memory exhaustion comes here.  |
`-------------------------------------------------*/
yyexhaustedlab:
  yyerror (YY_("memory exhausted"));
  yyresult = 2;
  /* Fall through.  */
#endif

yyreturn:
  if (yychar != YYEOF && yychar != YYEMPTY)
     yydestruct ("Cleanup: discarding lookahead",
		 yytoken, &yylval);
  /* Do not reclaim the symbols of the rule which action triggered
     this YYABORT or YYACCEPT.  */
  YYPOPSTACK (yylen);
  YY_STACK_PRINT (yyss, yyssp);
  while (yyssp != yyss)
    {
      yydestruct ("Cleanup: popping",
		  yystos[*yyssp], yyvsp);
      YYPOPSTACK (1);
    }
#ifndef yyoverflow
  if (yyss != yyssa)
    YYSTACK_FREE (yyss);
#endif
#if YYERROR_VERBOSE
  if (yymsg != yymsgbuf)
    YYSTACK_FREE (yymsg);
#endif
  /* Make sure YYID is used.  */
  return YYID (yyresult);
}


#line 318 "/home/max/sfslite/1.2/rpcc/parse.yy"

symlist_t symlist;

static int
proc_compare (const void *_a, const void *_b)
{
  rpc_proc *a = (rpc_proc *) _a;
  rpc_proc *b = (rpc_proc *) _b;
  return a->val < b->val ? -1 : a->val != b->val;
}

static int
vers_compare (const void *_a, const void *_b)
{
  rpc_vers *a = (rpc_vers *) _a;
  rpc_vers *b = (rpc_vers *) _b;
  return a->val < b->val ? -1 : a->val != b->val;
}

void
checkliterals ()
{
  for (size_t i = 0; i < litq.size (); i++) {
    rpc_sym *s = &symlist.push_back ();
    s->settype (rpc_sym::LITERAL);
    *s->sliteral = litq[i];
  }
  litq.clear ();
}

static str
getnewid (str id)
{
  if (ids[id])
    yywarn ("redefinition of symbol " << id);
  else
    ids.insert (id);
  if (idprefix)
    id = idprefix << id;
  return id;
}

static str
getid (str id)
{
  if (idprefix && ids[id])
    id = idprefix << id;
  return id;
}

