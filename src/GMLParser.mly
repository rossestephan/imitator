/************************************************************
 *
 *                     IMITATOR II
 * 
 * Laboratoire Specification et Verification (ENS Cachan & CNRS, France)
 * Author:        Etienne Andre
 * Created       : 2011/11/23
 * Last modified : 2012/06/13
************************************************************/


%{
open ParsingStructure;;
open Global;;
open NumConst;;


let parse_error s =
	let symbol_start = symbol_start () in
	let symbol_end = symbol_end () in
	raise (ParsingError (symbol_start, symbol_end))
;;

let convert declarations locations transitions =
	(* SO FAR CONSIDER ONLY ONE AUTOMATON *)
	let init_location : string ref = ref "" in
	let ok = ref true in
	
	(* Hashtbl location_id -> location invariant *)
	let invariants = Hashtbl.create (List.length locations) in
	(* Hashtbl location_id -> name *)
	let location_names : (NumConst.t, string) Hashtbl.t = Hashtbl.create (List.length locations) in
	(* Hashtbl location_id -> list of transtions *)
	let location_transitions = Hashtbl.create (List.length locations) in
	(* List of sync labs *)
	let synclabs = ref [] in
	
	(* Iterate on location descriptions *)
	List.iter (fun location -> 
		let (location_id, (location_name, (is_init, is_final), invariant)) = location in
			(* Check if id is defined *)
			if (Hashtbl.mem location_names location_id) then (
				print_error ("Location id '" ^ (string_of_numconst location_id) ^ "' is used several times.");
				ok := false;
			);
			(* Warn if final *)
			if is_final then print_warning ("Location '" ^ location_name ^ "' is defined as final; this will not be taken into account.");
			(* Check if initial *)
			if is_init then (
				(* Check if another initial state is defined *)
				if !init_location <> "" then (
					print_error ("At least two locations ('" ^ location_name ^ "' and '" ^ (!init_location) ^ "') are defined as initial.");
					ok := false;
				);
				(* Update init *)
				init_location := location_name;
			);
			(* Add couple id, name *)
			Hashtbl.add location_names location_id location_name;
			(* Add couple id, invariant *)
			Hashtbl.add invariants location_id invariant;
	) locations;
	
	(* Iterate on transitions descriptions *)
	List.iter (fun transition -> 
		let source_id, target_id, (label, guard, updates) = transition in
			(* Find source and target names *)
			if Hashtbl.mem location_names source_id && Hashtbl.mem location_names target_id then (
(* 				let source_name = Hashtbl.find location_names source_id in *)
				let target_name = Hashtbl.find location_names target_id in
				(* type transition = guard * update list * sync * location_name *)
				let new_transition = guard, updates, label, target_name in
				(* Add transition *)
				let _ =
				try (
					let list_of_transitions = Hashtbl.find location_transitions source_id in
					Hashtbl.replace location_transitions source_id (new_transition :: list_of_transitions);
				) with Not_found -> (
					Hashtbl.add location_transitions source_id [new_transition];
				);
				in ();
				(* Add sync lab if real sync lab *)
				match label with
					| NoSync -> ()
					| Sync sync_name -> synclabs := sync_name :: !synclabs;
			) else (
				ok := false;
				if not (Hashtbl.mem location_names source_id) then
					print_error ("No source location of id '" ^ (string_of_numconst source_id) ^ "' has been defined.");
				if not (Hashtbl.mem location_names target_id) then
					print_error ("No target location of id '" ^ (string_of_numconst target_id) ^ "' has been defined.");
			);
	) transitions;
	
	(* Don't go further *)
	if (not !ok) then raise InvalidProgram;

	(* Make transitions *)
	let locations = Hashtbl.fold (fun location_id location_name current_list ->
		(* Get info *)
		let location_name = Hashtbl.find location_names location_id in
		let transitions = try (Hashtbl.find location_transitions location_id) with Not_found -> [] in
		let invariant = Hashtbl.find invariants location_id in
		(* Make structure *)
		(* WARNING: stopwatches and costs not taken into account yet !! *)
		let location = location_name , None , invariant , [], List.rev transitions in
		(* Add it *)
		location :: current_list
	) location_names [] in
	
	let automaton_name = "only_one_automaton" in
	
	(* Name x list of synclabs x locations *)
	let automaton = automaton_name, list_only_once(!synclabs), List.rev locations in
	
	(* Make init *)
	
	let init_definition = 
		if (!init_location = "") then (
			[]
		)
		else [Loc_assignment (automaton_name , (!init_location))]
	in
	
	[automaton], init_definition
 
%}

%token <string> FLOAT
%token <NumConst.t> INT
%token <string> NAME
%token <string> STR_FLOAT
%token <NumConst.t> STR_INT

/* %token OP_PLUS OP_MINUS OP_MUL OP_DIV */
%token OP_MINUS OP_DIV OP_EQ

  

%token OPEN_ARC OPEN_ATTRIBUTE OPEN_MODEL OPEN_NODE OPEN_XML
%token OPEN_END_ARC OPEN_END_ATTRIBUTE OPEN_END_MODEL OPEN_END_NODE
%token CLOSE CLOSE_XML
%token SINGLE_CLOSE 

%token STR_AND STR_BOOLEXPR STR_CLOCK STR_CLOCKS STR_CONST STR_CONSTANTS STR_DECLARATION STR_GLOBALCONSTANTS STR_DISCRETE STR_DISCRETES STR_EXPR STR_FINALSTATE STR_FORMALISM_URL STR_GUARD STR_INITIALCONSTRAINT STR_INITIALSTATE STR_INVARIANT STR_LABEL STR_NAME STR_PARAMETER STR_PARAMETERS STR_STATE STR_TRANSITION  STR_TYPE STR_UPDATE STR_UPDATES STR_UTF8 STR_VARIABLES STR_XMLNS
%token STR_OPL STR_OPLEQ STR_OPEQ STR_OPGEQ STR_OPG
%token STR_OPMUL

%token CT_ARCTYPE CT_ENCODING CT_FORMALISMURL CT_ID CT_NAME CT_NODETYPE CT_SOURCE CT_TARGET CT_VERSION CT_XMLNS

%token EOF


%start main             /* the entry point */
%type <ParsingStructure.parsing_structure> main
%%




/************************************************************/
main:
	 header body footer EOF
	{
		let declarations, states, transitions = $2 in
		let automata, init_definition = convert declarations states transitions in
		declarations, automata, init_definition, []
	}
;

/************************************************************
  HEADER
************************************************************/

header:
/* <?xml version="1.0" encoding="UTF-8"?> */
	OPEN_XML CT_VERSION OP_EQ STR_FLOAT CT_ENCODING OP_EQ STR_UTF8 CLOSE_XML
/* <model formalismUrl="http://alligator.lip6.fr/timed-automata.fml" xmlns="http://gml.lip6.fr/model"> */
	OPEN_MODEL CT_FORMALISMURL OP_EQ STR_FORMALISM_URL CT_XMLNS OP_EQ STR_XMLNS CLOSE { }
;

footer:
	OPEN_END_MODEL CLOSE { }
;

/************************************************************
  USEFUL THINGS
************************************************************/
open_attribute:
	OPEN_ATTRIBUTE CT_NAME OP_EQ { }
;

close_attribute:
	OPEN_END_ATTRIBUTE CLOSE { }
;



/************************************************************
  BODY
************************************************************/
body:
/* 	TODO: allow different orders, even all mixed together  */
	| declarations initial states transitions { $1, $3, $4 } /*TODO: constraint*/ 
/* 	| declarations states { $1, [], [], [] } */
;

/************************************************************
  VARIABLES AND CONSTANTS
************************************************************/
declarations:
/* 1 shift / reduce conflict here! */
	| open_attribute STR_DECLARATION CLOSE
	variables constants
	close_attribute
		{ List.rev_append $4 $5 }
;



/*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
  Variables
-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*/

variables:
	| { [] }
/*     <attribute name="variables"> */
	| open_attribute STR_VARIABLES CLOSE
		variables_body
		close_attribute { $4 }
;

variables_body:
/* 	TODO: allow several definitions of clocks and discrete, all mixed together  */
	| { [] }
	| clocks { [$1] }
	| discretes { [$1] }
	| clocks discretes { [ $1 ; $2 ] }
	| discretes clocks { [ $1 ; $2 ] }
;



/*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
  Constants
-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*/

constants:
	| { [] }
/*     <attribute name="constants"> */
	| open_attribute STR_CONSTANTS CLOSE
		constants_body
		close_attribute { $4 }
;

constants_body:
/* 	TODO: allow several definitions of constants and parameters, all mixed together  */
	| { [] }
// 	TODO: Global constants not yet supported 
// 	| globalconstants { [$1] }
	| parameters { [$1] }
// 	| globalconstants parameters { [ $1 ; $2 ] }
// 	| parameters globalconstants { [ $1 ; $2 ] }
;



/*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
  Clocks
-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*/

clocks:
	| open_attribute STR_CLOCKS CLOSE
		list_of_clocks
		close_attribute { (Var_type_clock, $4) }
;

list_of_clocks:
	| { [] }
	| clock list_of_clocks { $1 :: $2 }
;

clock:
	| open_attribute STR_CLOCK CLOSE
		NAME
		close_attribute
			{ ($4, None) }
;

/*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
  Discretes
-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*/

discretes:
	| open_attribute STR_DISCRETES CLOSE
		list_of_discretes
		close_attribute { (Var_type_discrete, $4) }
;

list_of_discretes:
	| { [] }
	| discrete list_of_discretes { $1 :: $2 }
;

discrete:
	| open_attribute STR_DISCRETE CLOSE
		NAME
		close_attribute
			{ ($4, None) }
;

/*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
  Global constants
-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*/

// TODO: NOT YET SUPPORTED
// globalconstants:
// 	| open_attribute STR_GLOBALCONSTANTS CLOSE
// 		list_of_names_with_values
// /* 		TO DO: add type constant ! */
// 		close_attribute { (Var_type_parameter, $4) }
// ;


/*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
  Parameters
-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*/

parameters:
	| open_attribute STR_PARAMETERS CLOSE
		list_of_parameters
		close_attribute { (Var_type_parameter, $4) }
;

list_of_parameters:
	| { [] }
	| parameter list_of_parameters { $1 :: $2 }
;

parameter:
	| open_attribute STR_PARAMETER CLOSE
		NAME
		close_attribute
			{ ($4, None) }
;

/************************************************************
  INITIAL CONSTRAINT
************************************************************/
initial:
	| { [] } /*true is an empty list of constraint*/
	| initial_constraint { $1 }
;

initial_constraint:
	| open_attribute STR_INITIALCONSTRAINT CLOSE
	bool_expr
	close_attribute { $4 }
;


/************************************************************
  STATES
************************************************************/
states:
	| state states { $1 :: $2 }
	| { [] }
;

state:
/* <node id="2" nodeType="state"> */
	| OPEN_NODE CT_ID OP_EQ STR_INT CT_NODETYPE OP_EQ STR_STATE CLOSE
		state_attributes
		OPEN_END_NODE CLOSE { $4, $9 }
;

state_attributes:
/* TO DO: allow different orders! */
/* WARNING: stopwatches non allowed yet !! */
/* WARNING: 1 shift/reduce conflict here because of non-empty invariant  */
	| name state_type state_invariant { $1, $2, $3 }
	| name state_type { $1, $2, [] }
	| name state_invariant { $1, (false, false), $2 }
	| name { $1, (false, false), [] }
;

/*<node id="1" nodeType="state">
        <attribute name="name">p</attribute>
        <attribute name="type">
            <attribute name="initialState"/>
            <attribute name="finalState"/>
        </attribute>
    </node>*/

/*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
  Type
-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*/

state_type:
	/* <attribute name="type"/> */
	| open_attribute STR_TYPE SINGLE_CLOSE { false, false }

	/* <attribute name="type"> [...] </attribute> */
	| state_open
	close_attribute { false, false }

	| state_open
	state_type_init 
	close_attribute { $2, false }

	| state_open
	 state_type_final
	close_attribute { false, $2 }

	| state_open
	state_type_init state_type_final
	close_attribute { $2, $3 }

	| state_open
	state_type_final state_type_init
	close_attribute { $3, $2 }
;

state_open:
	open_attribute STR_TYPE CLOSE {}
;

state_type_init:
/* <attribute name="initialState"/> */
	| open_attribute STR_INITIALSTATE SINGLE_CLOSE { true }
;

state_type_final:
	| open_attribute STR_FINALSTATE SINGLE_CLOSE { true }
;


/*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
  Invariant
-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*/

state_invariant:
	/* <attribute name="invariant"> [...] </attribute> */
	| open_attribute STR_INVARIANT CLOSE
	bool_expr
	close_attribute { $4 }

	/* <attribute name="invariant"></attribute> */
	| open_attribute STR_INVARIANT CLOSE
	close_attribute { [] }

	/* <attribute name="invariant" /> */
	| open_attribute STR_INVARIANT SINGLE_CLOSE { [] }
;


/************************************************************
  TRANSITIONS
************************************************************/
transitions:
	| transition transitions { $1 :: $2 }
	| { [] }
;

transition:
    /*<arc id="5" arcType="transition" source="1" target="2">*/
	| OPEN_ARC CT_ID OP_EQ STR_INT CT_ARCTYPE OP_EQ STR_TRANSITION CT_SOURCE OP_EQ STR_INT CT_TARGET OP_EQ STR_INT CLOSE
	transition_body
	OPEN_END_ARC CLOSE { $10, $13, $15 }
;

transition_body:
	/* TO IMPROVE ! */
	| label guard updates { $1, $2, $3 }
	| label guard { $1, $2, [] }
	| label updates { $1, [], $2 }
	| guard updates { NoSync, $1, $2 }
	| label { $1, [], [] }
	| guard { NoSync, $1, [] }
	| updates { NoSync, [], $1 }
	| { NoSync, [], [] }
;

/*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
  Label
-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*/
label:
	/*<attribute name="label">a</attribute>*/
	| open_attribute STR_LABEL CLOSE 
	NAME
	close_attribute { Sync $4 }
/* 	|  { NoSync } */
;

/*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
  Guard
-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*/

guard:
	/*<attribute name="guard"> [...] </attribute>*/
	| open_attribute STR_GUARD CLOSE 
	bool_expr
	close_attribute { $4 }

	| open_attribute STR_GUARD CLOSE 
 	close_attribute { [] } 

	| open_attribute STR_GUARD SINGLE_CLOSE { [] }

/* 	| { [] } */
;


/*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
  Updates
-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*/

updates:
	| open_attribute STR_UPDATES CLOSE 
	update_list
	close_attribute { $4 }

	/*<attribute name="updates"/>*/
	| open_attribute STR_UPDATES SINGLE_CLOSE { [] }
	
	
/* 	| { [] } */
;

update_list:
	| update update_list { $1 :: $2 }
	| { [] }
;

update:
	| /*<attribute name="update">*/
	open_attribute STR_UPDATE CLOSE
	/*<attribute name="name">y</attribute>*/
	name
	expression
	close_attribute { $4, $5 }
;

/************************************************************
  BOOLEAN EXPRESSIONS
************************************************************/
bool_expr:
	/* TO DO: allow true and false! */
	|  open_attribute STR_BOOLEXPR CLOSE
	conjunction
	close_attribute { $4 }
;

conjunction:
	|  open_attribute STR_AND CLOSE
	conjunction
	comparison
	close_attribute { $5 :: $4 }

// uncommenting these 2 rules creates conflict!
/*	|  open_attribute STR_AND CLOSE
	conjunction
	conjunction
	close_attribute { List.rev_append $7 $6 }*/
	
/*	|  open_attribute STR_AND CLOSE
	comparison
	conjunction
	close_attribute { $6 :: $7 }*/
	
	| comparison { [$1] }
;

comparison:
	open_attribute op CLOSE
	expression
	expression
	close_attribute { Linear_constraint ($4 , $2 , $5) }
;


/*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
  Operators
-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*/

op:
	| STR_OPL	{ OP_L }
	| STR_OPLEQ	{ OP_LEQ }
	| STR_OPEQ	{ OP_EQ }
	| STR_OPGEQ	{ OP_GEQ }
	| STR_OPG	{ OP_G }
;


/************************************************************
  EXPRESSIONS
************************************************************/
expression:
	| open_attribute STR_EXPR CLOSE
		linear_expression
		close_attribute { $4 }
;


linear_expression:
	| linear_term { Linear_term $1 }
;

linear_term:
	| const { Constant $1 }
	| var { $1 }
;

var:
	| name { Variable (NumConst.one, $1) }
	| open_attribute STR_OPMUL CLOSE
	const name
	close_attribute { Variable ($4, $5) }
;


const:
	/*<attribute name="const">4</attribute>*/
	open_attribute STR_CONST CLOSE
	rational
	close_attribute
		{ $4 } 
;


/************************************************************
  NAME
************************************************************/

name:
/* <attribute name="name">q</attribute> */
	| open_attribute STR_NAME CLOSE
		NAME
		close_attribute { $4 }
;


// list_of_names_with_values:
// 	| name_with_value list_of_names_with_values { $1 :: $2 }
// 	| { [] }
// ;
// 
// 
// name_with_value:
// 	open_attribute STR_NAME CLOSE
// 		NAME
// 		close_attribute { ($4, None) }
// ;


/************************************************************
  NUMBERS
************************************************************/

rational:
	integer { $1 }
	| float { $1 }
	| integer OP_DIV pos_integer { (NumConst.div $1 $3) }
;

integer:
	pos_integer { $1 }
	| OP_MINUS pos_integer { NumConst.neg $2 }
;

pos_integer:
	INT { $1 }
;

float:
  pos_float { $1 }
	| OP_MINUS pos_float { NumConst.neg $2 }  
;

pos_float:
  FLOAT { 
		let fstr = $1 in
		let point = String.index fstr '.' in
		(* get integer part *)
		let f = if point = 0 then ref NumConst.zero else (
			let istr = String.sub fstr 0 point in
		  ref (NumConst.numconst_of_int (int_of_string istr))
		) in		
		(* add decimal fraction part *)
		let numconst_of_char = function
			| '0' -> NumConst.zero
			| '1' -> NumConst.one
			| '2' -> NumConst.numconst_of_int 2
			| '3' -> NumConst.numconst_of_int 3
			| '4' -> NumConst.numconst_of_int 4
			| '5' -> NumConst.numconst_of_int 5
			| '6' -> NumConst.numconst_of_int 6
			| '7' -> NumConst.numconst_of_int 7
			| '8' -> NumConst.numconst_of_int 8
			| '9' -> NumConst.numconst_of_int 9
			| _ ->  raise (ParsingError (0,0)) in
		let ten = NumConst.numconst_of_int 10 in
		let dec = ref (NumConst.numconst_of_frac 1 10) in
		for i = point+1 to (String.length fstr) - 1 do
			let c = fstr.[i] in
			let d = numconst_of_char c in
			f := NumConst.add !f (NumConst.mul !dec d);
			dec := NumConst.div !dec ten 
		done;		
		!f
	} 
;