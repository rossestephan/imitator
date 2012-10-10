(***************************************************
 *
 *                     IMITATOR II
 * 
 * Laboratoire Specification et Verification (ENS Cachan & CNRS, France)
 * Author:        Etienne Andre
 * Created:       2009/12/02
 * Last modified: 2012/06/15
 *
 **************************************************)


open Global
open AbstractModel


(**************************************************)
(** Program *)
(**************************************************)

(* Convert a var_type into a string *)
let string_of_var_type = function
	| Var_type_clock -> "clock"
	| Var_type_discrete -> "discrete"
	| Var_type_parameter -> "parameter"

(* Add a header to the program *)
let string_of_header program =
	let options = Input.get_options () in
		"(**************************************************"
	^ "\n" ^" * Program " ^ options#file
(* 	^ "\n" ^" * Generated at time " ^ time? *)
	^ "\n" ^" **************************************************)"

(* Convert the initial variable declarations into a string *)
let string_of_declarations program =
	"var "
	^
	let string_of_variables list_of_variables =
		string_of_list_of_string_with_sep ", " (List.map program.variable_names list_of_variables) in
	(if program.nb_clocks > 0 then
		("\n\t" ^ (string_of_variables program.clocks) ^ "\n\t\t: clock;") else "")
	^
	(if program.nb_discrete > 0 then
		("\n\t" ^ (string_of_variables program.discrete) ^ "\n\t\t: discrete;") else "")
	^
	(if program.nb_parameters > 0 then
		("\n\t" ^ (string_of_variables program.parameters) ^ "\n\t\t: parameter;") else "")

(* Convert the synclabs of an automaton into a string *)
let string_of_synclabs program automaton_index =
	"synclabs: "
	^ (let synclabs, _ = (List.fold_left (fun (synclabs, first) action_index ->
		match program.action_types action_index with
		(* Case sync: declare *)
		| Action_type_sync ->
			synclabs
			^ (if not first then ", " else "")
			^ (program.action_names action_index)
			(* Not the first one anymore *)
			, false
		(* Case nosync: do not declare *)
		| Action_type_nosync -> (synclabs, first)
	) ("", true) (program.actions_per_automaton automaton_index)) in synclabs)
	^ ";"


(* Convert the initially of an automaton into a string *)
let string_of_initially program automaton_index =
	let inital_global_location  = program.initial_location in
	let initial_location = Automaton.get_location inital_global_location automaton_index in
	"initally: "
	^ (program.location_names automaton_index initial_location)
	^ ";"


(* Convert the invariant of a location into a string *)
let string_of_invariant program automaton_index location_index =
	"while "
	^ (LinearConstraint.string_of_linear_constraint program.variable_names (program.invariants automaton_index location_index))
	^ " wait"


(* Convert a sync into a string *)
let string_of_sync program action_index =
	match program.action_types action_index with
	| Action_type_sync -> " sync " ^ (program.action_names action_index)
	| Action_type_nosync -> " (* sync " ^ (program.action_names action_index) ^ "*) "



let string_of_clock_updates program = function
	| No_update -> ""
	| Resets list_of_clocks -> 
		string_of_list_of_string_with_sep ", " (List.map (fun variable_index ->
			(program.variable_names variable_index)
			^ "' = 0"
		) list_of_clocks)
	| Updates list_of_clocks_lt -> 
		string_of_list_of_string_with_sep ", " (List.map (fun (variable_index, linear_term) ->
			(program.variable_names variable_index)
			^ "' = "
			^ (LinearConstraint.string_of_linear_term program.variable_names linear_term)
		) list_of_clocks_lt)

	
	
(* Convert a list of updates into a string *)
let string_of_updates program updates =
	string_of_list_of_string_with_sep ", " (List.map (fun (variable_index, linear_term) ->
		(* Convert the variable name *)
		(program.variable_names variable_index)
		^ "' = "
		(* Convert the linear_term *)
		^ (LinearConstraint.string_of_linear_term program.variable_names linear_term)
	) updates)


(* Convert a transition of a location into a string *)
let string_of_transition program automaton_index action_index (guard, clock_updates, discrete_updates, destination_location) =
	"\n\t" ^ "when "
	(* Convert the guard *)
	^ (LinearConstraint.string_of_linear_constraint program.variable_names guard)

	(* Convert the updates *)
	^ " do {"
	(* Clock updates *)
	^ (string_of_clock_updates program clock_updates)
	(* Add a coma in case of both clocks and discrete *)
	^ (if clock_updates != No_update && discrete_updates != [] then ", " else "")
	(* Discrete updates *)
	^ (string_of_updates program discrete_updates)
	^ "} "
	
	(* Convert the sync *)
	^ (string_of_sync program action_index)
	(* Convert the destination location *)
	^ " goto " ^ (program.location_names automaton_index destination_location)
	^ ";"


(* Convert the transitions of a location into a string *)
let string_of_transitions program automaton_index location_index =
	string_of_list_of_string (
	(* For each action *)
	List.map (fun action_index -> 
		(* Get the list of transitions *)
		let transitions = program.transitions automaton_index location_index action_index in
		(* Convert to string *)
		string_of_list_of_string (
			(* For each transition *)
			List.map (string_of_transition program automaton_index action_index) transitions
			)
		) (program.actions_per_location automaton_index location_index)
	)


(* Convert a location of an automaton into a string *)
let string_of_location program automaton_index location_index =
	"\n" ^ "loc: "
	^ (program.location_names automaton_index location_index)
	^ (match program.costs automaton_index location_index with
		| None -> ""
		| Some cost -> "[" ^ (LinearConstraint.string_of_linear_term program.variable_names cost) ^ "]"
	)
	^ ": "
	^ (string_of_invariant program automaton_index location_index)
	^ (string_of_transitions program automaton_index location_index)


(* Convert the locations of an automaton into a string *)
let string_of_locations program automaton_index =
	string_of_list_of_string_with_sep "\n " (List.map (fun location_index ->
		string_of_location program automaton_index location_index
	) (program.locations_per_automaton automaton_index))


(* Convert an automaton into a string *)
let string_of_automaton program automaton_index =
	"\n(**************************************************)"
	^ "\n automaton " ^ (program.automata_names automaton_index)
	^ "\n(**************************************************)"
	^ "\n " ^ (string_of_synclabs program automaton_index)
	^ "\n " ^ (string_of_initially program automaton_index)
	^ "\n " ^ (string_of_locations program automaton_index)
	^ "\n end (* " ^ (program.automata_names automaton_index) ^ " *)"
	^ "\n(**************************************************)"


(* Convert the automata into a string *)
let string_of_automata program =
	string_of_list_of_string_with_sep "\n\n" (
		List.map (fun automaton_index -> string_of_automaton program automaton_index
	) program.automata)

(* Convert the program into a string *)
let string_of_program program =
	string_of_header program
	^  "\n" ^ string_of_declarations program
	^  "\n" ^ string_of_automata program
	(** TODO: the initial constraint !! *)


(**************************************************)
(** States *)
(**************************************************)

(* Convert a location name into a string *)
(*let string_of_location_name program location =
	let string_array = List.map (fun automaton_index location_index ->
		program.automata_names.(automaton_index) ^ ": " ^ (program.location_names automaton_index location_index)
	) location in
	string_of_array_of_string_with_sep ", " string_array*)

(* Convert a state into a string *)
let string_of_state program (global_location, linear_constraint) =
	"" ^ (Automaton.string_of_location program.automata_names program.location_names program.variable_names global_location) ^ " ==> \n&" ^ (LinearConstraint.string_of_linear_constraint program.variable_names linear_constraint) ^ "" 


(**************************************************)
(** Pi0 *)
(**************************************************)
(* Convert a pi0 into a string *)
let string_of_pi0 program pi0 =
	"  " ^ (
	string_of_list_of_string_with_sep "\n& " (
		List.map (fun parameter ->
			(program.variable_names parameter)
			^ " = "
			^ (NumConst.string_of_numconst (pi0 parameter))
		) program.parameters
	)
	)



(**************************************************************)
(* Result *)
(**************************************************************)
(*(** Constraint returned by the inverse method *)
type returned_constraint =
	(** Constraint under convex form *)
	| Convex_constraint of LinearConstraint.linear_constraint
	(** Disjunction of constraints *)
	| Union_of_constraints of LinearConstraint.linear_constraint list*)
let string_of_returned_constraint variable_names = function 
	| Convex_constraint linear_constraint -> LinearConstraint.string_of_linear_constraint variable_names linear_constraint
	(** Disjunction of constraints *)
	| Union_of_constraints k_list -> string_of_list_of_string_with_sep "\n OR \n" (List.map (LinearConstraint.string_of_linear_constraint variable_names) k_list)
