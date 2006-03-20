:- module(pce_xref_gui,
	  [ pce_xref/0
	  ]).
:- use_module(pce).
:- use_module(persistent_frame).
:- use_module(tabbed_window).
:- use_module(toolbar).
:- use_module(pce_report).
:- use_module(pce_util).
:- use_module(pce_toc).
:- use_module(pce_arm).
:- use_module(pce_prolog_xref).
:- use_module(tabular).
:- use_module(library(lists)).
:- use_module(library(debug)).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
XPCE based font-end of the Prolog cross-referencer.  Tasks:

	* Cross-reference currently loaded program
	* Generate module-dependency graph
	* Information on
		- Syntax and other encountered errors
		- Export/Import relation between modules
		- Undefined predicates
		- Unused predicates
	* Summary information
		- Syntax and other encountered errors
		- Exports never used (not for libs!)
		- Undefined predicates
		- Undefined predicates
	* Export module import header
		- Using require/1
		- Using use_module/1
		- Using use_module/2

Requires two types of files

		- Application
		- Libraries		% Files under file_search_path(library)

================================================================
NOTE: This is work in progress.  It is very incomplete and most
likely not ready for real use.

Its in CVS as this makes it easier to maintain and brave people
can have a look and make sugestions.
================================================================
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

pce_xref :-
	send(new(XREF, prolog_xref), open),
	send(XREF, wait),
	send(XREF, update).


:- pce_begin_class(prolog_xref, persistent_frame,
		   "GUI for the Prolog cross-referencer").

initialise(F) :->
	send_super(F, initialise, 'Prolog XREF'),
	new(BrowserTabs, tabbed_window),
	send(BrowserTabs, left, new(WSTabs, tabbed_window)),
	send(BrowserTabs, name, browsers),
	send(WSTabs, name, workspaces),
	send_list([BrowserTabs, WSTabs], label_popup, F?tab_popup),
	send(new(TD, tool_dialog(F)), above, BrowserTabs),
	send(new(report_dialog), below, BrowserTabs),
	send(F, append, BrowserTabs),
	send_list(BrowserTabs,
		  [ append(new(xref_file_tree), files),
		    append(new(prolog_xref_predicate_list), predicates)
		  ]),
	send_list(WSTabs,
		  [ append(new(prolog_xref_depgraph), dependencies)
		  ]),
	send(F, fill_toolbar, TD).
	
tab_popup(_F, P:popup) :<-
	"Popup for tab labels"::
	new(P, popup),
	send_list(P, append,
		  [ menu_item(close, message(@arg1, destroy)),
		    menu_item(detach, message(@arg1, untab))
		  ]).

fill_toolbar(F, TD:tool_dialog) :->
	send(TD, append, new(File, popup(file))),
	send_list(File, append,
		  [ menu_item(exit, message(F, destroy))
		  ]).

:- pce_group(parts).

workspace(F, Which:name, Create:[bool], Expose:bool, WS:window) :<-
	"Find named workspace"::
	get(F, member, workspaces, Tabs),
	(   get(Tabs, member, Which, WS)
	->  true
	;   Create == @on
	->  workspace_term(Which, New),
	    new(WS, New),
	    send(WS, name, Which),
	    send(Tabs, append, WS)
	),
	(   Expose == @on
	->  send(Tabs, on_top, WS?name)
	;   true
	).

workspace_term(file_info, prolog_file_info).
	    
browser(F, Which:name, Browser:browser) :<-
	"Find named browser"::
	get(F, member, browsers, Tabs),
	get(Tabs, member, Which, Browser).

update(F) :->
	"Update all windows"::
	send(F, xref_all),
	get(F, member, browsers, Tabs),
	send(Tabs?members, for_some,
	     message(@arg1, update)).

xref_all(F) :->
	"Run X-referencer on all files"::
	forall(source_file(File),
	       send(F, xref_file, File)).

xref_file(F, File:name) :->
	"XREF a single file if not already done"::
	(   xref_done(File, Time),
	    catch(time_file(File, Modified), _, fail),
	    Modified < Time
	->  true
	;   send(F, report, progress, 'XREF %s', File),
	    xref_source(File),
	    send(F, report, done)
	).

:- pce_group(actions).


file_info(F, File:name) :->
	"Show summary info on File"::
	get(F, workspace, file_info, @on, @on, Window),
	send(Window, file, File).

:- pce_end_class(prolog_xref).


		 /*******************************
		 *	      WORKSPACE		*
		 *******************************/

:- pce_begin_class(prolog_xref_depgraph, picture,
		   "Workspace showing dependecies").

:- pce_end_class(prolog_xref_depgraph).


		 /*******************************
		 *	     FILE TREE		*
		 *******************************/

:- pce_begin_class(xref_file_tree, toc_window,
		   "Show loaded files as a tree").
:- use_class_template(arm).

initialise(Tree) :->
	send_super(Tree, initialise),
	send(Tree, clear).

collapse_node(_, _:any) :->
	true.

expand_node(_, _:any) :->
	true.

update(FL) :->
	send(FL, clear),
	send(FL, append_all_sourcefiles).

append_all_sourcefiles(FL) :->
	"Append all files loaded into Prolog"::
	forall(source_file(File),
	       send(FL, append, File)),
	send(FL, sort).

clear(Tree) :->
	"Remove all nodes, recreate the toplevel"::
	send_super(Tree, clear),
	send(Tree, root, new(Root, toc_folder(project, project))),
	send(Tree, son, project, toc_folder('.', '.')),
	send(Tree, son, project, toc_folder(alias, alias)),
	send(Tree, son, project, toc_folder(/, /)),
	send(Root, for_all, message(@arg1, collapsed, @off)).

append(Tree, File:name) :->
	"Add Prolog source file"::
	send(Tree, append_node, new(prolog_file_node(File))).
	
append_node(Tree, Node:toc_node) :->
	"Append a given node to the tree"::
	get(Node, parent_id, ParentId),
	(   get(Tree, node, ParentId, Parent)
	->  true
	;   send(Tree, append_node,
		 new(Parent, prolog_directory_node(ParentId)))
	),
	send(Parent, son, Node).
	
sort(Tree) :->
	forall(member(Name, [alias, '.', /]),
	       (   get(Tree, node, Name, Node),
		   send(Node, sort_sons, ?(@arg1, compare, @arg2))
	       )).

select_node(Tree, File:name) :->
	"User selected a node"::
	(   exists_file(File)
	->  send(Tree?frame, file_info, File)
	;   true
	).

:- pce_end_class(xref_file_tree).


:- pce_begin_class(prolog_directory_node, toc_folder,
		   "Represent a directory").

initialise(DN, Dir:name) :->
	"Create a directory node"::
	(   alias_path(Name, Dir)
	->  true
	;   file_base_name(Dir, Name)
	),
	send_super(DN, initialise, Name, Dir).

parent_id(FN, ParentId:name) :<-
	"Get id for the parent"::
	get(FN, identifier, Path),
	(   alias_path(_, Path)
	->  ParentId = alias
	;   file_directory_name(Path, ParentId)
	).

sort(DN) :->
	"Sort my sons"::
	send(DN, sort_sons, ?(@arg1, compare, @arg2)),
	send(DN?sons, for_all, message(@arg1, sort)).

compare(DN, Node:toc_node, Diff:{smaller,equal,larger}) :<-
	"Compare for sorting children"::
	(   send(Node, instance_of, prolog_file_node)
	->  Diff = smaller
	;   get(DN, label, L1),
	    get(Node, label, L2),
	    get(L1, compare, L2, Diff)
	).

:- pce_end_class(prolog_directory_node).


:- pce_begin_class(prolog_file_node, toc_file,
		   "Represent a file").

initialise(FN, File:name) :->
	"Create from a file"::
	absolute_file_name(File, Path),
	send_super(FN, initialise, new(T, xref_file_text(Path)), Path),
	send(T, default_action, info).

parent_id(FN, ParentId:name) :<-
	"Get id for the parent"::
	get(FN, identifier, Path),
	file_directory_name(Path, Dir),
	(   alias_path('.', Dir)
	->  ParentId = '.'
	;   ParentId = Dir
	).

sort(_) :->
	true.

compare(FN, Node:toc_node, Diff:{smaller,equal,larger}) :<-
	"Compare for sorting children"::
	(   send(Node, instance_of, prolog_directory_node)
	->  Diff = larger
	;   get(FN, label, L1),
	    get(Node, label, L2),
	    get(L1, compare, L2, Diff)
	).

:- pce_end_class(prolog_file_node).




		 /*******************************
		 *	     FILE INFO		*
		 *******************************/


:- pce_begin_class(prolog_file_info, window,
		   "Show information on File").
:- use_class_template(arm).

variable(tabular,     tabular, get, "Displayed table").
variable(prolog_file, name*,   get, "Displayed Prolog file").

initialise(W, File:[name]*) :->
	send_super(W, initialise),
	send(W, pen, 0),
	send(W, scrollbars, vertical),
	send(W, display, new(T, tabular)),
	send(T, rules, all),
	send(T, cell_spacing, -1),
	send(W, slot, tabular, T),
	(   atom(File)
	->  send(W, prolog_file, File)
	;   true
	).

resize(W) :->
	send_super(W, resize),
	get(W?visible, width, Width),
	send(W?tabular, table_width, Width-3).


file(V, File0:name*) :->
	"Set vizualized file"::
	(   File0 == @nil
	->  File = File0
	;   absolute_file_name(File0, File)
	),
	(   get(V, prolog_file, File)
	->  true
	;   send(V, slot, prolog_file, File),
	    send(V, update)
	).


clear(W) :->
	send(W?tabular, clear).


update(V) :->
	"Show information on the current file"::
	send(V, clear),
	(   get(V, prolog_file, File),
	    File \== @nil
	->  send(V, show_info)
	;   true
	).


:- pce_group(info).

show_info(W) :->
	get(W, tabular, T),
	BG = (background := khaki1),
	get(W, prolog_file, File),

	send(T, append, File, huge, center, colspan := 2, BG),
	send(T, next_row),
	send(W, show_module),
	send(W, show_modified),
	send(W, show_exports),
	true.

show_module(W) :->
	"Show basic module info"::
	get(W, prolog_file, File),
	get(W, tabular, T),
	(   xref_module(File, Module)
	->  send(T, append, 'Module:', bold, right),
	    send(T, append, Module),
	    send(T, next_row)
	;   true
	).

show_modified(W) :->
	get(W, prolog_file, File),
	get(W, tabular, T),
	time_file(File, Stamp),
	convert_time(Stamp, Modified),
	send(T, append, 'Modified:', bold, right),
	send(T, append, Modified),
	send(T, next_row).

show_exports(W) :->
	get(W, prolog_file, File),
	(   xref_module(File, Module),
	    findall(E, xref_exported(File, E), Exports),
	    Exports \== []
	->  get(W, tabular, T),
	    BG = (background := khaki1),
	    send(T, append, 'Export', huge, center, BG),
	    send(T, append, 'Imported by', huge, center, BG),
	    send(T, next_row),
	    sort_callables(Exports, Sorted),
	    forall(member(Callable, Sorted),
		   send(W, show_export, File, Module, Callable))
	;   true
	).

show_export(W, File:name, Module:name, Callable:prolog) :->
	get(W, tabular, T),
	send(T, append, xref_predicate_text(Module:Callable, @off)),
	findall(In, exported_to(File, Callable, In), InL),
	send(T, append, new(XL, xref_imported_by_list)),
	(   InL == []
	->  true
	;   sort_files(InL, Sorted),
	    forall(member(F, Sorted),
		   send(XL, append, xref_imported_by(F, Callable)))
	),
	send(T, next_row).
	
%	exported_to(+ExportFile, +Callable, -ImportFile)
%	
%	ImportFile imports Callable from ExportFile.  The second clause
%	deals with auto-import.
%	
%	TBD: Make sure the autoload library is loaded before we begin.

exported_to(ExportFile, Callable, ImportFile) :-
	xref_defined(ImportFile, Callable, imported(ExportFile)),
	atom(ImportFile).		% avoid XPCE buffers.
exported_to(ExportFile, Callable, ImportFile) :-
	'$autoload':library_index(Callable, _, ExportFileNoExt),
	file_name_extension(ExportFileNoExt, _, ExportFile),
	xref_called(ImportFile, Callable),
	\+ xref_defined(ImportFile, Callable, _).


:- pce_end_class(prolog_file_info).


:- pce_begin_class(xref_predicate_text, text,
		   "Text representing a predicate").

class_variable(colour, colour, dark_green).

variable(pi,	prolog,	get, "Predicate indicator").

initialise(T, Spec:prolog, Qualify:[bool]) :->
	"Create from callable or predicate indicator"::
	to_predicate_indicator(Spec, PI),
	send(T, slot, pi, PI),
	unqualify(Qualify, PI, Term),
	term_to_atom(Term, Text),
	send_super(T, initialise, Text).
       

unqualify(@off, _:PI, PI) :- !.
unqualify(_, PI, PI).


:- pce_global(@xref_predicate_text_recogniser,
	      new(handler_group(@arm_recogniser,
				click_gesture(left, '', single, 
					      message(@receiver, edit))))).

event(T, Ev:event) :->
	(   send_super(T, event, Ev)
	->  true
	;   send(@xref_predicate_text_recogniser, event, Ev)
	).


arm(TF, Val:bool) :->
	"Preview activiity"::
	(   Val == @on
	->  send(TF, underline, @on),
	    send(TF, report, status, 'Predicate %s', TF?string)
	;   send(TF, underline, @off),
	    send(TF, report, status, '')
	).

edit(T) :->
	get(T, pi, PI),
	edit(PI).

:- pce_end_class(xref_predicate_text).


:- pce_begin_class(xref_file_text, text,
		   "Represent a file-name").

variable(path,		 name,	       get, "Filename represented").
variable(default_action, name := edit, both, "Default on click").

initialise(TF, File:name) :->
	absolute_file_name(File, Path),
	short_file_name(Path, ShortId),
	short_file_name_to_atom(ShortId, Label),
	send_super(TF, initialise, Label),
	send(TF, slot, path, Path).

:- pce_global(@xref_file_text_recogniser,
	      make_xref_file_text_recogniser).

make_xref_file_text_recogniser(G) :-
	new(C, click_gesture(left, '', single, 
			     message(@receiver, run_default_action))),
	new(G, handler_group(C, @arm_recogniser)).

event(T, Ev:event) :->
	(   send_super(T, event, Ev)
	->  true
	;   send(@xref_file_text_recogniser, event, Ev)
	).

arm(TF, Val:bool) :->
	"Preview activiity"::
	(   Val == @on
	->  send(TF, underline, @on),
	    send(TF, report, status, 'File %s', TF?path)
	;   send(TF, underline, @off),
	    send(TF, report, status, '')
	).

run_default_action(T) :->
	get(T, default_action, Def),
	send(T, Def).

edit(T) :->
	get(T, path, Path),
	edit(file(Path)).

info(T) :->
	get(T, path, Path),
	send(T?frame, file_info, Path).

:- pce_end_class(xref_file_text).


:- pce_begin_class(xref_imported_by, figure,
		   "Indicate import of callable into file").

variable(pi, prolog, get, "PI of imported predicate").

:- pce_global(@xref_horizontal_format,
	      make_xref_horizontal_format).

make_xref_horizontal_format(F) :-
	new(F, format(vertical, 1, @on)),
	send(F, row_sep, 3),
	send(F, column_sep, 0).

initialise(IT, File:name, Imported:prolog) :->
	send_super(IT, initialise),
	send(IT, format, @xref_horizontal_format),
	send(IT, display, new(F, xref_file_text(File))),
	send(F, name, file_text),
	to_predicate_indicator(Imported, PI),
	send(IT, slot, pi, PI),
	send(IT, show_called_by).
	
path(IT, Path:name) :<-
	"Represented file"::
	get(IT, member, file_text, Text),
	get(Text, path, Path).

callable(IT, Callable:prolog) :<-
	get(IT, pi, PI),
	to_callable(PI, Callable).

show_called_by(IT) :->
	"Add number indicating calls"::
	get(IT, called_by, List),
	length(List, N),
	send(IT, display, new(T, text(string('(%d)', N)))),
	send(T, name, called_count),
	(   N > 0
	->  send(T, underline, @on),
	    send(T, colour, blue),
	    send(T, recogniser, @xref_called_by_recogniser)
	;   send(T, colour, grey60)
	).

called_by(IT, ByList:prolog) :<-
	"Return list of callables satisfied by the import"::
	get(IT, path, Source),
	get(IT, callable, Callable),
	findall(By, used_in(Source, Callable, By), ByList).

%	used_in(+Source, +Callable, -CalledBy)

used_in(Source, Callable, By) :-
	xref_called(Source, Callable, By).
used_in(Source, Callable, '<export>') :-
	xref_exported(Source, Callable).

:- pce_group(event).

:- pce_global(@xref_called_by_recogniser,
	      new(popup_gesture(@receiver?device?called_by_popup, left))).

called_by_popup(IT, P:popup) :<-
	"Show called where import is called"::
	new(P, popup(called_by, message(IT, edit_called_by, @arg1))),
	get(IT, called_by, ByList),
	sort_callables(ByList, Sorted),
	forall(member(C, Sorted),
	       ( callable_to_label(C, Label),
		 send(P, append, menu_item(prolog(C), @default, Label)))).

edit_called_by(IT, Called:prolog) :->
	"Edit file on the predicate Called"::
	get(IT, path, Source),
	(   Called == '<export>'
	->  edit(file(Source))
	;   xref_defined(Source, Called, Def)
	->  (   Def = local(Line)
	    ->  edit(file(Source, line(Line)))
	    ;   term_to_atom(Def, Text),
		send(IT, report, warning, 'Don''t know how to edit %s', Text)
	    )
	).

:- pce_end_class(xref_imported_by).


:- pce_begin_class(xref_imported_by_list, figure,
		   "Show list of exports to files").

variable(wrap, {extend,wrap,wrap_fixed_width,clip} := extend, get,
	 "Wrapping mode").

initialise(XL) :->
	send_super(XL, initialise),
	send(XL, margin, 500, wrap).

append(XL, I:xref_imported_by) :->
	(   send(XL?graphicals, empty)
	->  true
	;   send(XL, display, text(', '))
	),
	send(XL, display, I).

:- pce_group(layout).

:- pce_global(@xref_imported_by_list_format,
	      make_xref_imported_by_list_format).

make_xref_imported_by_list_format(F) :-
	new(F, format(horizontal, 500, @off)),
	send(F, column_sep, 0),
	send(F, row_sep, 0).

margin(T, Width:int*, How:[{wrap,wrap_fixed_width,clip}]) :->
	"Wrap items to indicated width"::
	(   Width == @nil
	->  send(T, slot, wrap, extend),
	    send(T, format, @rdf_composite_format)
	;   send(T, slot, wrap, How),
	    How == wrap
	->  new(F, format(horizontal, Width, @off)),
	    send(F, column_sep, 0),
	    send(F, row_sep, 0),
	    send(T, format, F)
	;   tbd
	).

:- pce_end_class(xref_imported_by_list).



		 /*******************************
		 *	    PREDICATES		*
		 *******************************/

:- pce_begin_class(prolog_xref_predicate_list, browser,
		 "Show loaded files").

update(_) :-> true.

:- pce_end_class(prolog_xref_predicate_list).


		 /*******************************
		 *	   UTIL CLASSES		*
		 *******************************/

:- pce_begin_class(formatted_view, view,
		   "View with additional facilities for formatting").

initialise(V) :->
	send_super(V, initialise),
	send(V, font, normal),
	send_list(V,
		  [ style(h1, style(font := huge)),
		    style(h2, style(font := large)),
		    style(b,  style(font := bold)),
		    style(tt, style(font := fixed)),
		    style(predicate, style(colour := dark_green,
					   underline := @on))
		  ]),
	send(V?image, recogniser,
	     click_gesture(left, '', single,
			   message(V, clicked,
				   ?(@receiver, index, @event)))).

format(V, Style:name, Format:name, Args:prolog, OnClick:[prolog]) :->
	"Append using Prolog format"::
	sformat(String, Format, Args),
	get(V, text_buffer, TB),
	get(TB, size, Size0),
	send(TB, append, String),
	atom_length(String, Len),
	new(_, formatted_view_fragment(TB, Size0, Len, Style, OnClick)),
	send(V, caret, TB?size).

append_callable(V, Callable:prolog, Qualify:[bool]) :->
	predicate_indicator(Callable, PI),
	send(V, append_predicate_indicator, PI, Qualify).

append_predicate_indicator(V, PI0:prolog, Qualify:bool) :->
	(   Qualify == @off
	->  strip_module(PI0, _, PI)
	;   PI = PI0
	),
	send(V, format, predicate, '~w', PI, edit(PI0)).

clicked(V, At:int) :->
	"User clicked at caret position"::
	send(V, caret, At),
	(   get(V, find_fragment, message(@arg1, overlap, At), Frag),
	    send(Frag, has_send_method, execute),
	    send(Frag, execute)
	->  true
	;   true
	).

:- pce_group(event).


:- pce_end_class(formatted_view).


:- pce_begin_class(formatted_view_fragment, fragment).

variable(on_click, prolog*, both, "Associated action").

initialise(F, TB:text_buffer, Start:int, Len:int, Style:name,
	   OnClick:[prolog]) :->
	send_super(F, initialise, TB, Start, Len, Style),
	send(F, include, both, @off),
	(   OnClick \== @default
	->  send(F, slot, on_click, OnClick)
	;   true
	).

execute(F) :->
	"Exevute associated action"::
	get(F, on_click, Goal),
	Goal \== @nil,
	Goal.

:- pce_end_class(formatted_view_fragment).



		 /*******************************
		 *	  LOGIC (MAY MOVE)	*
		 *******************************/

%	short_file_name(+File, -ShortId)
%	
%	Create a short name for a file

short_file_name(Path, ShortId) :-
	(   alias_path(Alias, Dir),
	    atom_concat(Dir, Local, Path)
	->  (   Alias == '.'
	    ->  ShortId = Local
	    ;   file_name_extension(Base, pl, Local)
	    ->  ShortId =.. [Alias, Base]
	    ;   ShortId =.. [Alias, Local]
	    )
	;   ShortId = Path
	).
	
%	short_file_name_to_atom(+ShortId, -Atom)
%	
%	Convert a short filename into an atom

short_file_name_to_atom(Atom, Atom) :-
	atomic(Atom), !.
short_file_name_to_atom(Term, Atom) :-
	term_to_atom(Term, Atom).


%	alias_path(-Alias, ?Dir)
%	
%	Enumerate the defined aliases, sorting   them  starting with the
%	longest path-name, so the first hit is immediately the best one.

:- dynamic
	alias_cache/2.

alias_path(Alias, Dir) :-
	(   alias_cache(_, _)
	->  true
	;   build_alias_cache
	),
	(   nonvar(Dir)
	->  ensure_slash(Dir, DirSlash),
	    alias_cache(Alias, DirSlash)
	;   alias_cache(Alias, Dir)
	).

build_alias_cache :-
	findall(t(DirLen, AliasLen, Alias, Dir),
		search_path(Alias, Dir, AliasLen, DirLen), Ts),
	sort(Ts, List0),
	reverse(List0, List),
	forall(member(t(_, _, Alias, Dir), List),
	       assert(alias_cache(Alias, Dir))).

search_path('.', Here, 999, DirLen) :-
	working_directory(Here0, Here0),
	ensure_slash(Here0, Here),
	atom_length(Here, DirLen).
search_path(Alias, Dir, AliasLen, DirLen) :-
	file_search_path(Alias, _),
	Spec =.. [Alias,'.'],
	atom_length(Alias, AliasLen0),
	AliasLen is 1000 - AliasLen0,	% must do reverse sort
	absolute_file_name(Spec, Dir0,
			   [ file_type(directory),
			     access(read),
			     solutions(all)
			   ]),
	ensure_slash(Dir0, Dir),
	atom_length(Dir, DirLen).

ensure_slash(Dir, Dir) :-
	sub_atom(Dir, _, _, 0, /), !.
ensure_slash(Dir0, Dir) :-
	atom_concat(Dir0, /, Dir).

%	library_file(+Path)
%	
%	True if Path comes from the Prolog tree and must be considered a
%	library.

library_file(Path) :-
	current_prolog_flag(home, Home),
	sub_atom(Path, 0, _, _, Home).


%	sort_files(+Files, -Sorted)
%	
%	Sort files, keeping groups comming from the same alias together.

sort_files(Files0, Sorted) :-
	sort(Files0, Files),		% remove duplicates
	maplist(key_file, Files, Keyed),
	keysort(Keyed, KSorted),
	unkey(KSorted, Sorted).

key_file(File, Key-File) :-
	short_file_name(File, Key).


		 /*******************************
		 *	     PREDICATES		*
		 *******************************/

%	to_predicate_indicator(+Term, -PI)
%	
%	Convert to a predicate indicator.

to_predicate_indicator(PI, PI) :-
	is_predicate_indicator(PI), !.
to_predicate_indicator(Callable, PI) :-
	callable(Callable),
	predicate_indicator(Callable, PI).

%	is_predicate_indicator(=PI)
%	
%	True if PI is a predicate indicator.

is_predicate_indicator(Name/Arity) :-
	atom(Name),
	integer(Arity).
is_predicate_indicator(Module:Name/Arity) :-
	atom(Module),
	atom(Name),
	integer(Arity).

%	predicate_indicator(+Callable, -Name)
%	
%	Generate a human-readable predicate indicator

predicate_indicator(Module:Goal, PI) :-
	atom(Module), !,
	predicate_indicator(Goal, PI0),
	(   hidden_module(Module)
	->  PI = PI0
	;   PI = Module:PI0
	).
predicate_indicator(Goal, Name/Arity) :-
	callable(Goal), !,
	functor(Goal, Name, Arity).
predicate_indicator(Goal, Goal).

hidden_module(user) :- !.
hidden_module(system) :- !.
hidden_module(M) :-
	sub_atom(M, 0, _, _, $).

%	to_callable(+PI, -Callable)
%	to_callable(+Callable, -Callable)
%	
%	Convert to a callable term

to_callable(Module:PI, Callable) :-
	atom(Module), !,
	to_callable(PI, Callable).
to_callable(Name/Arity, Callable) :- !,
	functor(Callable, Name, Arity).
to_callable(Callable, Callable) :-
	callable(Callable), !.
to_callable(In, _) :-
	throw(error(type_error(In, callable_or_pi), _)).

%	sort_callables(+List, -Sorted)
%	
%	Sort list of callable terms.

sort_callables(Callables, Sorted) :-
	key_callables(Callables, Tagged),
	keysort(Tagged, KeySorted),
	unkey(KeySorted, Sorted).

key_callables([], []).
key_callables([H0|T0], [k(Name, Arity, Module)-H0|T]) :-
	predicate_indicator(H0, PI),
	(   PI = Name/Arity
	->  Module = user
	;   PI = Module:Name/Arity
	),
	key_callables(T0, T).
	
unkey([], []).
unkey([_-H|T0], [H|T]) :-
	unkey(T0, T).

%	callable_to_label(+Callable, -Label)

callable_to_label(pce_principal:send_implementation(Id,_,_), Id) :-
	atom(Id), !.
callable_to_label(pce_principal:get_implementation(Id,_,_,_), Id) :-
	atom(Id), !.
callable_to_label('<export>', '<export>').
callable_to_label(Callable, Label) :-
	to_predicate_indicator(Callable, PI),
	unqualify(@off, PI, T0),
	term_to_atom(T0, Label).
