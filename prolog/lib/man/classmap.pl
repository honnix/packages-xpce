/*  $Id$

    Part of XPCE
    Designed and implemented by Anjo Anjewierden and Jan Wielemaker
    E-mail: jan@swi.psy.uva.nl

    Copyright (C) 1994 University of Amsterdam. All rights reserved.
*/

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Temporary hack to allow storing  the   documentation-files  onto the 8+3
limited DOS filesystem.  These names will   eventually  be stored in the
class-structure itself for easier maintenance.  Grrrrrrr #$%!$@%##%!
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- module(pce_class_map, [mapped_class_name/2]).

mapped_class_name(*,                       times).
mapped_class_name(+,                       plus).
mapped_class_name(-,                       minus).
mapped_class_name(/,                       divide).
mapped_class_name(:=,                      binding).
mapped_class_name(<,                       less).
mapped_class_name(=,                       eq).
mapped_class_name(=<,                      lesseq).
mapped_class_name(==,                      equal).
mapped_class_name(>,                       greater).
mapped_class_name(>=,                      greateq).
mapped_class_name(?,                       obtain).
mapped_class_name(\==,                     noteq).
mapped_class_name(@=,			   nameref).
