/*  Part of XPCE --- The SWI-Prolog GUI toolkit

    Author:        Jan Wielemaker and Anjo Anjewierden
    E-mail:        jan@swi.psy.uva.nl
    WWW:           http://www.swi.psy.uva.nl/projects/xpce/
    Copyright (c)  1995-2011, University of Amsterdam
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:

    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in
       the documentation and/or other materials provided with the
       distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/

:- module(require, [require/1]).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
This file defines the  Prolog  predicate   require/1  which  allows  for
portable loading of libraries on  systems   with  a  Quintus-like module
system.  require/1 are part of both  SWI-Prolog and SICStus Prolog.  For
other Prologs this module should be ported to the Prolog system and made
part of the module `pce', so any PCE/Prolog program can start with:

:- module(foobar,
	  [ foobar/1,
	    ...
	  ]).
:- use_module(library(pce)).
:- require([ member/1
	   , forall/2
	   , send_list/3
	   ]).

without having to worry about the available system predicates, autoload
libraries, library structure, etc.

This software was originally written for the SWI-Prolog autoloader.

Auto_call/1 added for xpce 4.8.6
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- meta_predicate
	require(:).


:- use_module(pce_utils, [strip_module/3]).


require(Spec) :-
	strip_module(Spec, Module, Predicates),
	require(Module, Predicates).


require(_, []) :- !.
require(Module, [H|T]) :- !,
	require(Module, H),
	require(Module, T).
require(_Module, Name/Arity) :-		% a builtin
	functor(Head, Name, Arity),
	predicate_property(Head, built_in).
require(Module, Name/Arity) :-		% already defined
	functor(Head, Name, Arity),
	current_predicate(Name, Module:Head), !.
require(Module, Name/Arity) :-		% load from library
	load_library_index,
	functor(Head, Name, Arity),
	library_index(Head, _, File),
	Module:use_module(library(File), [Name/Arity]).
require(_Module, Name/Arity) :-
	print_message(error, required_predicate_not_found(Name,Arity)).

te_require_list(Specs, UseModules) :-
	load_library_index,
	map_requirements(Specs, Libs),
	combine_use_modules(Libs, UseModules).

map_requirements([], []) :- !.
map_requirements([Name/Arity|Tail], List) :-
        functor(Head, Name, Arity),
	(   predicate_property(Head, built_in)
	->  List = ListRest
	;   library_index(Head, _, File)
	->  List = [lib(File, Head)|ListRest]
	;   print_message(warning, required_predicate_not_found(Name,Arity)),
	    List = ListRest
	),
	map_requirements(Tail,ListRest).

combine_use_modules([], []).
combine_use_modules([lib(Lib, Term)|Rest],
		    [(:- use_module(library(Lib), [Name/Ar|Ps])), RestDecl]) :-
	functor(Term, Name, Ar),
	collect_for_lib(Rest, Lib, Ps, [], R0),
	combine_use_modules(R0, RestDecl).

collect_for_lib([], _, [], R, R).
collect_for_lib([lib(Lib, Term)|L], Lib, [Name/Arity|RH], R0, R) :- !,
	functor(Term, Name, Arity),
	collect_for_lib(L, Lib, RH, R0, R).
collect_for_lib([LT|L], Lib, RH, R0, R) :-
	collect_for_lib(L, Lib, RH, [LT|R0], R).


		/********************************
		*           LOAD INDEX		*
		********************************/

:- dynamic
	library_index/3.			% Head x Module x Path

load_library_index :-
	library_index(_, _, _), !.		% loaded
load_library_index :-
	absolute_file_name(library('QPINDEX.pl'),
			   [ access(read),
			     file_errors(fail)
			   ], Index),
	!,
        read_index(Index),
	(   absolute_file_name(library('INDEX.pl'),
			       [ access(read),
				 file_errors(fail),
				 solutions(all)
			       ], LibIndex),
	    read_index(LibIndex),
	    fail
	;   true
	).
load_library_index :-
	print_message(warning, index_not_found(library('QPINDEX.pl'))).

read_index(Index) :-
	seeing(Old), see(Index),
	repeat,
	    read(Term),
	    (   Term == end_of_file
	    ->  !
	    ;   assert_index(Term, Index),
	        fail
	    ),
	seen, see(Old),
	print_message(informational, loaded_library_index(Index)).

assert_index(index(Name, Arity, Module, File), _Index) :- !,
	functor(Head, Name, Arity),
	assertz(library_index(Head, Module, File)).
assert_index(Term, Index) :-
	print_message(warning, illegal_term_in_index(Term,Index)).

