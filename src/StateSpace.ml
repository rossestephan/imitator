(************************************************************
 *
 *                       IMITATOR
 * 
 * Laboratoire Spécification et Vérification (ENS Cachan & CNRS, France)
 * LIPN, Université Paris 13, Sorbonne Paris Cité (France)
 * 
 * Module description: Description of the symbolic states and of the state space
 * 
 * File contributors : Ulrich Kühne, Étienne André
 * Created           : 2009/12/08
 * Last modified     : 2016/05/04
 *
 ************************************************************)



(************************************************************)
(* Modules *)
(************************************************************)
(*module Ppl = Ppl_ocaml
open Ppl*)

open Exceptions
open OCamlUtilities
open ImitatorUtilities
open Automaton
open AbstractModel
open State



(************************************************************)
(** Nature of a state space according to some property *)
(************************************************************)
type statespace_nature =
	| Good
	| Bad
	| Unknown



(************************************************************)
(** Set of state index *)
(************************************************************)

(* state struct for constructing set type *)
module State = struct
	type t = state_index
	let compare = compare
end

(* set of states for efficient lookup *)
module StateIndexSet = Set.Make(State)



(************************************************************)
(** State space structure *)
(************************************************************)
type state_space = {
	(** The number of generated states (even not added to the state space) *)
	nb_generated_states : int ref;

	(** An Array 'state_index' -> 'abstract_state'; contains ALL states *)
	all_states : (state_index, abstract_state) Hashtbl.t;
	
	(** The id of the initial state *)
	(*** NOTE: mutable due to the fact that the initial state can be merged with another state *)
	mutable initial : state_index option;
	
	(** A hashtable location -> location_index *)
	index_of_locations : (Location.global_location, location_index) Hashtbl.t;

	(** A DynArray location_index -> location *)
	locations : Location.global_location DynArray.t;

	(** A hashtable to quickly find states with identical locations (? ; made by Ulrich); only for states to be compared *)
	states_for_comparison : (int, state_index) Hashtbl.t;

	(** A hashtable '(state_index, action_index)' -> 'target_state_index' *)
	transitions_table : ((state_index * action_index), state_index) Hashtbl.t;

	(** An integer that remembers the next index of state_index (may not be equal to the number of states, if states are removed *)
	next_state_index : state_index ref;
}


(************************************************************)
(** Constant *)
(************************************************************)
(** Initial size of the array of states (will be updated automatically *)
let initial_size = 100


(************************************************************)
(** Statistics *)
(************************************************************)
(*** TODO: move to a statistics class / object ***)
let nb_state_comparisons = ref 0
let nb_constraint_comparisons = ref 0


(************************************************************)
(** State space creation *)
(************************************************************)

(** Create a fresh state space *)
let make guessed_nb_transitions = 
	(* Create a Hashtbl : state_index -> (location_index, linear_constraint) for the reachable states *)
	let states = Hashtbl.create initial_size in
	(* Create a hashtable : location -> location_index for the locations *)
	let index_of_locations = Hashtbl.create initial_size in
	(* Create a DynArray : location_index -> location for the locations *)
	let locations = DynArray.make initial_size in
	(* Create an empty lookup table : hash -> state_index *)
	let states_for_comparison = Hashtbl.create initial_size in
	(* Create a hashtable for the state space *)
	let transitions_table = Hashtbl.create guessed_nb_transitions in
	
	(* Create the state space *)
	{
		nb_generated_states = ref 0;
		all_states = states;
		initial = None;
		index_of_locations = index_of_locations;
		locations = locations;
		states_for_comparison = states_for_comparison;
		transitions_table = transitions_table;
		next_state_index = ref 0;
	}


(************************************************************)
(** Interrogation on a state space *)
(************************************************************)

(** Return the number of generated states (not necessarily present in the state space) *)
let get_nb_gen_states state_space =
	!(state_space.nb_generated_states)

(** Return the number of states in a state space *)
let nb_states state_space =
	Hashtbl.length state_space.all_states


(** Return the number of transitions in a state space *)
let nb_transitions state_space =
	Hashtbl.length state_space.transitions_table


(* Return the global_location corresponding to a location_index *)
let get_location state_space location_index =
	DynArray.get state_space.locations location_index


(** Return the state of a state_index *)
let get_state state_space state_index =
	(* Find the couple (location_index, constraint) *)
	let location_index, linear_constraint =
		(* Exception just in case *)
		try (
			Hashtbl.find state_space.all_states state_index
		) with Not_found -> raise (InternalError ("State of index '" ^ (string_of_int state_index) ^ "' was not found in state_space (function: get_state)."))
	in
	(* Find the location *)
	let global_location = get_location state_space location_index in
	(* Return the state *)
	(global_location, linear_constraint)


(** Return the index of the initial state, or raise Not_found if not defined *)
let get_initial_state_index state_space =
	match state_space.initial with
	| Some state_index -> state_index
	| None -> raise Not_found


(*(** Return the initial state, or raise Not_found if not defined *)
let get_initial_state state_space =
	get_state state_space (get_initial_state_index state_space)*)


(** Return the table of transitions *)
let get_transitions state_space =
	state_space.transitions_table


(** Compte and return the list of index successors of a state *)
let get_successors state_space state_index =
	(* Retrieve the model *)
	let model = Input.get_model() in
	
	List.fold_left (fun succs action_index -> 
		try (
			let succ = Hashtbl.find_all state_space.transitions_table (state_index, action_index) in
			List.rev_append succ succs 
		) with Not_found -> succs
	) [] model.actions


(** Compte and return the list of pairs (index successor of a state, corresponding action) *)
let get_successors_with_actions state_space state_index =
	(* Retrieve the model *)
	let model = Input.get_model() in
	
	List.fold_left (fun succs action_index -> 
		try (
			let succ = Hashtbl.find_all state_space.transitions_table (state_index, action_index) in
			let succ_with_action = List.map (fun state_index -> state_index , action_index) succ in
			List.rev_append succ_with_action succs
		) with Not_found -> succs
	) [] model.actions


(*------------------------------------------------------------*)
(** Compute and return a predecessor table state_index -> (state_index, action_index) list *)
(*------------------------------------------------------------*)
let compute_predecessors_with_actions state_space =
	(* Retrieve the model *)
	let model = Input.get_model() in

	(* Create a hash table for predecessors: state_index -> (state_index, action_index) list *)
	let predecessors = Hashtbl.create (Hashtbl.length state_space.all_states) in
	
	(* Iterate on all states in the state space *)
	Hashtbl.iter(fun source_state_index _ ->
		(* Iterate on actions, and fill *)
		List.iter (fun action_index -> 
			(* Test if the origin state has some transitions with this action *)
			if Hashtbl.mem state_space.transitions_table (source_state_index, action_index) then(
				(* Find successors for this action and transition *)
				let successors = Hashtbl.find_all state_space.transitions_table (source_state_index, action_index) in
				
				(* Update the predecessors hash table for each successor *)
				List.iter (fun target_state_index -> 
					(* Retrieve the predecessors of target_state_index, if any *)
					let current_predecessors = if Hashtbl.mem predecessors target_state_index then Hashtbl.find predecessors target_state_index else [] in
					
					(*** NOTE: state_index may be added several times (is that a problem…?) ***)
					let updated_predecessors = (source_state_index, action_index) :: current_predecessors in
					
					(* Update predecessors *)
					Hashtbl.replace predecessors target_state_index updated_predecessors;
				) successors;
			);
		) model.actions;
	) state_space.all_states;
	
	(* Return structure *)
	predecessors


(** Return the list of all state indexes *)
let all_state_indexes state_space = hashtbl_get_all_keys state_space.all_states
(*let all_state_indexes state_space =
	Hashtbl.fold
		(fun state_index _ current_list ->
			state_index :: current_list)
		state_space.all_states []*)

	

(*** WARNING: big memory, here! Why not perform intersection on the fly? *)

(** Return the list of all constraints on the parameters associated to the states of a state space *)
let all_p_constraints state_space =
	Hashtbl.fold
		(fun _ (_, linear_constraint) current_list ->
			let p_constraint = LinearConstraint.px_hide_nonparameters_and_collapse linear_constraint in
			p_constraint :: current_list)
		state_space.all_states []



(** Iterate over the reahable states *)
let iterate_on_states f state_space =
	Hashtbl.iter f state_space.all_states


(*(** Compute the intersection of all parameter constraints, DESTRUCTIVE!!! *)
(** HERE PROBLEM IF ONE WANTS TO COMPUTE THE states FILE AFTER **)
let compute_k0_destructive program state_space =
	let k0 = LinearConstraint.true_constraint () in
	iterate_on_states (fun _ (_, constr) -> 
		LinearConstraint.hide_assign program.clocks_and_discrete constr;
		LinearConstraint.px_intersection_assign k0 [constr];

	) state_space;
	k0*)

(** find all "last" states on finite or infinite runs *)
(* Uses a depth first search on the reachability state_space. The *)
(* prefix of the current DFS path is kept during the search *)
(* in order to detect cycles. *) 
let last_states model state_space =
	(* list to keep the resulting last states *)
	let last_states = ref [] in
	(* Table to keep all states already visited during DFS *)
	let dfs_table = ref StateIndexSet.empty in

	(* functional version for lookup *)
	let already_seen node = StateIndexSet.mem node !dfs_table in
	
	(* function to find all last states *)
	let rec cycle_detect node prefix =
		(* get all successors of current node *)
		let succs = get_successors state_space node in
		if succs = [] then
			(* no successors -> last node on finite path *)
			last_states := node :: !last_states
		else (
			(* insert node in DFS table *)
			dfs_table := StateIndexSet.add node !dfs_table;
			(* go on with successors *)
			List.iter (fun succ -> 
				(* successor in current path prefix (or self-cycle)? *)
				if succ = node || StateIndexSet.mem succ prefix then
					(* found cycle *)
					last_states := succ :: !last_states
				else if not (already_seen succ) then
					(* go on recursively on newly found node *)
					cycle_detect succ (StateIndexSet.add node prefix)					
			) succs;
		) in
		
	(* start cycle detection with initial state *)
	cycle_detect 0 StateIndexSet.empty;
	
	(* return collected last states *)
	!last_states


(*exception Satisfied

(** Checks if a state exists that satisfies a given predicate *)
let exists_state p state_space =
		try (
			iter (fun s -> 
				if p s then raise Satisfied
			) state_space;
			false
		) with Satisfied -> true

(** Checks if all states satisfy a given predicate *)
let forall_state p state_space =
		try (
			iter (fun s -> 
				if not (p s) then raise Satisfied
			) state_space;
			true
		) with Satisfied -> false	*)	



(*(** Check if bad states are reachable *)
let is_bad program state_space =
	(* get bad state pairs from program *)
	let bad_states = program.bad in
	(* if no bad state specified, then must be good *)
	if bad_states = [] then false else (
		let is_bad_state = fun (location, _) -> 
			List.for_all (fun (aut_index, loc_index) -> 
				loc_index = Location.get_location location aut_index
			) bad_states in
		exists_state is_bad_state state_space
	) *)


(************************************************************)
(** Actions on a state space *)
(************************************************************)
exception Found of state_index

(** Increment the number of generated states (even though not member of the state space) *)
let increment_nb_gen_states state_space =
	state_space.nb_generated_states := !(state_space.nb_generated_states) + 1


(** compute a hash code for a state, depending only on the location *)
let hash_code (location, _) =
	Location.hash_code location


(** Check if two states are equal *)
let states_equal state1 state2 =
	let (loc1, constr1) = state1 in
	let (loc2, constr2) = state2 in
	if not (Location.location_equal loc1 loc2) then false else (
		(* Statistics *)
		print_message Verbose_high ("About to compare equality between two constraints.");
		nb_constraint_comparisons := !nb_constraint_comparisons + 1;
		print_message Verbose_high ("Already performed " ^ (string_of_int (!nb_constraint_comparisons)) ^ " constraint comparison" ^ (s_of_int !nb_constraint_comparisons) ^ ".");
		LinearConstraint.px_is_equal constr1 constr2
	)
	
(* Check dynamically if two states are equal*)
let states_equal_dyn state1 state2 constr =
	let (loc1, constr1) = state1 in
	let (loc2, constr2) = state2 in
	if not (Location.location_equal loc1 loc2) then false else (
		(* Statistics *)
		print_message Verbose_high ("About to compare (dynamic) equality between two constraints.");
		nb_constraint_comparisons := !nb_constraint_comparisons + 1;
		print_message Verbose_high ("Already performed " ^ (string_of_int (!nb_constraint_comparisons)) ^ " constraint comparison" ^ (s_of_int !nb_constraint_comparisons) ^ ".");
		(*** WARNING!!! Really sure that one wants do MODIFY the constraints here?!!! ***)
		LinearConstraint.px_intersection_assign constr1  [constr];
		LinearConstraint.px_intersection_assign constr2 [constr];
		LinearConstraint.px_is_equal constr1 constr2
	)


(** Check if a state is included in another one *)
(* (Despite the test based on the hash table, this is still necessary in case of hash collisions) *)
let state_included state1 state2 =
	let (loc1, constr1) = state1 in
	let (loc2, constr2) = state2 in
	if not (Location.location_equal loc1 loc2) then false else (
		(* Statistics *)
		print_message Verbose_high ("About to compare inclusion between two constraints.");
		nb_constraint_comparisons := !nb_constraint_comparisons + 1;
		print_message Verbose_high ("Already performed " ^ (string_of_int (!nb_constraint_comparisons)) ^ " constraint comparison" ^ (s_of_int !nb_constraint_comparisons) ^ ".");
		LinearConstraint.px_is_leq constr1 constr2
	)


(** Perform the insertion of a new state in a state space *)
let insert_state state_space hash new_state =
	(* Compute the new state index *)
	let new_state_index = !(state_space.next_state_index) in
	(* Retrieve the location and the constraint *)
	let location, linear_constraint = new_state in
	(* Try to find the location index *)
	let location_index = try (
		Hashtbl.find state_space.index_of_locations location
	) with Not_found -> (
	(* If not found: add it *)
		(* Find new index *)
		let new_index = Hashtbl.length state_space.index_of_locations in
		(* Add to hash table *)
		Hashtbl.add state_space.index_of_locations location new_index;
		(* Add to Dyn Array *)
		DynArray.add state_space.locations location;
		(* Check length (COULD BE REMOVED) *)
		if DynArray.length state_space.locations != Hashtbl.length state_space.index_of_locations then(
			raise (InternalError "Locations and index_of_locations seem not to be consistent anymore.");
		);
		(* Return new index *)
		new_index;
	) in
	
	
	
(*	print_warning "warning: consistency check";
	(* Consistency check: the state should NOT be present (otherwise this is a duplicate) *)
	Hashtbl.iter (fun state_index _ ->
(* 		print_string "."; *)
		let state = get_state state_space state_index in
		if states_equal state new_state then(
			raise (InternalError "Trying to add a state that is present");
		);
	) state_space.all_states;*)
	
	(* Set the initial state if not yet set *)
	if state_space.initial = None then(
		print_message Verbose_low ("Initial state set in the reachability state_space.");
		state_space.initial <- Some new_state_index;
	);
	
	
	(* Add the state to the tables *)
	Hashtbl.add state_space.all_states new_state_index (location_index, linear_constraint);
	Hashtbl.add state_space.states_for_comparison hash new_state_index;
	(* Update next state index *)
	state_space.next_state_index := !(state_space.next_state_index) + 1;
	(* Return state_index *)
	new_state_index


(*(**** TO DO: merge with add_state !!! *)
(** Add a state to a state space, if it is not present yet with the on-the-fly intersection *)
let add_state_dyn program state_space new_state constr =
	(* Retrieve the input options *)
	let options = Input.get_options () in
	(* compute hash value for the new state *)
	let hash = hash_code new_state in
	if verbose_mode_greater Verbose_total then (
		print_message Verbose_standard ("hash : " ^ (string_of_int hash));
	); 
	(* In tree mode: does not test anything *)
	if options#tree then (
		(* Since the state does NOT belong to the state space: find the state index *)
		let new_state_index = insert_state state_space hash new_state in
		(* Return state_index, true *)
		new_state_index, true
	) else (
		(* The check used for equality *)
		let check_states = states_equal_dyn in
		try (
			(* use hash table to find states with same locations (modulo hash collisions) *)
			let old_states = Hashtbl.find_all state_space.states_for_comparison hash in
			if verbose_mode_greater Verbose_total then (
				let nb_old = List.length old_states in
				print_message Verbose_total ("hashed list of length " ^ (string_of_int nb_old));
			);
			
			(* Statistics *)
			print_message Verbose_medium ("About to compare new state with " ^ (string_of_int (List.length old_states)) ^ " state(s).");
			nb_state_comparisons := !nb_state_comparisons + (List.length old_states);
			print_message Verbose_medium ("Already performed " ^ (string_of_int (!nb_state_comparisons)) ^ " comparisons.");
			
			List.iter (fun index -> 
				let state = get_state state_space index in
				if check_states new_state state constr then raise (Found index)
			) old_states;
			(* Not found -> insert state *)
			let new_state_index = insert_state state_space hash new_state in
			(* Return state_index, true *)
			new_state_index, true				
		)	with Found state_index -> (
				state_index, false
		)
	)*)


(** Add a state to a state space, if it is not present yet *)
let add_state state_space new_state =
	(* Retrieve the input options *)
	let options = Input.get_options () in
	(* compute hash value for the new state *)
	let hash = hash_code new_state in
	if verbose_mode_greater Verbose_total then (
		print_message Verbose_total ("hash : " ^ (string_of_int hash));
	); 
	(* In tree mode: does not test anything *)
	if options#tree then (
		(* Since the state does NOT belong to the state space: find the state index *)
		let new_state_index = insert_state state_space hash new_state in
		(* Return state_index, true *)
		new_state_index, true
	) else (
		(* The check used for equality *)
		let check_states = if options#inclusion then state_included else states_equal in
		try (
			(* use hash table to find all states with same locations (modulo hash collisions) *)
			let old_states = Hashtbl.find_all state_space.states_for_comparison hash in
			if verbose_mode_greater Verbose_total then (
				let nb_old = List.length old_states in
				print_message Verbose_total ("hashed list of length " ^ (string_of_int nb_old));
			);

			(* Statistics *)
			print_message Verbose_medium ("About to compare new state with " ^ (string_of_int (List.length old_states)) ^ " state" ^ (s_of_int (List.length old_states)) ^ ".");
			nb_state_comparisons := !nb_state_comparisons + (List.length old_states);
			print_message Verbose_medium ("Already performed " ^ (string_of_int (!nb_state_comparisons)) ^ " comparison" ^ (s_of_int !nb_state_comparisons) ^ ".");
			
			List.iter (fun index -> 
				let state = get_state state_space index in
				if check_states new_state state then raise (Found index)
			) old_states;
			(* Not found -> insert state *)
			let new_state_index = insert_state state_space hash new_state in
			(* Return state_index, true *)
			new_state_index, true
		)	with Found state_index -> (
				state_index, false
		)
	)
			

			
let get_transitions_of_state state_space source_state_index action_index =
	try (
		Hashtbl.find_all state_space.transitions_table (source_state_index, action_index)
	)	with Not_found -> []


(** Add a transition to the state space. Transitions are unique in that this 
    function will refuse to add two transitions with the same source and
		target index and the same label. *)
let add_transition state_space (source_state_index, action_index, target_state_index) =
	(* check if it already exists *)
	let transitions = get_transitions_of_state state_space source_state_index action_index in
	if not (List.mem target_state_index transitions) then
		Hashtbl.add state_space.transitions_table (source_state_index, action_index) target_state_index


(*		
(** Add a transition to the state space *)
let add_transition state_space (source_state_index, action_index, target_state_index) =
	Hashtbl.add state_space.transitions_table (source_state_index, action_index) target_state_index*)


(** Add an inequality to all the states of the state space *)
(*** NOTE: it is assumed that the p_constraint does not render some states inconsistent! ***)
let add_p_constraint_to_states state_space p_constraint =
(* 	let constraint_to_add = LinearConstraint.make_p_constraint [inequality] in *)
	(* For all state: *)
	iterate_on_states (fun _ (_, constr) ->
		 LinearConstraint.px_intersection_assign_p constr [p_constraint]
	) state_space


(*
	CURRENTLY USELESS
(** Replace the constraint of a state in a state space by another one (the constraint is copied to avoid side-effects later) *)
let replace_constraint state_space linear_constraint state_index =
	(* Copy to avoid side-effects *)
	let linear_constraint_copy = LinearConstraint.copy linear_constraint in
	try (
		(* Get the location index *)
		let location_index, _ = Hashtbl.find state_space.all_states state_index in
		(* Replace with the new constraint *)
		Hashtbl.replace state_space.all_states state_index (location_index, linear_constraint_copy);
	) with Not_found -> raise (InternalError ("Error when handling state '" ^ (string_of_int state_index) ^ "' in Graph:replace_constraint."))*)

(*
(** Merge two states by replacing the second one with the first one, in the whole state_space structure (lists of states, and transitions) *)
let merge_2_states state_space state_index1 state_index2 =
	(* Retrieve state2 (for hash later *)
	let location_index2, constr2 = Hashtbl.find state_space.all_states state_index2 in
	let state2 = get_location state_space location_index2, constr2 in
	
	(*-------------------------------------------------------------*)
	(* Replace s2 with s1 in transition table *)
	(*-------------------------------------------------------------*)
	(* First copy the table (MEMORY CONSUMING! but necessary in order to avoid unexpected behaviors) *)
	let transitions_copy = Hashtbl.copy state_space.transitions_table in
	Hashtbl.iter (fun (source_state_index, action_index) target_state_index ->
		(* Replace if source *)
		if source_state_index = state_index2 then (
			(* Replace target if needed *)
			let new_target_state_index = if target_state_index = state_index2 then state_index1 else target_state_index in
			Hashtbl.remove state_space.transitions_table (source_state_index, action_index);
			if Hashtbl.mem state_space.transitions_table (state_index1, action_index) && (Hashtbl.find state_space.transitions_table (state_index1, action_index)) = new_target_state_index then (
				
				(* TO RECHECK (exception disabled by Etienne, 16/03/2012 *)

				
				(* Unexpected case *)
(* 				raise (InternalError ("Error when merging states: a couple '(source_state_index, action_index)' is already bound in the transitions table.")); *)
			)else
				Hashtbl.add state_space.transitions_table (state_index1, action_index) new_target_state_index;
		)
		(* Replace if target *)
		else (if target_state_index = state_index2 then (
			Hashtbl.remove state_space.transitions_table (source_state_index, action_index);
			if Hashtbl.mem state_space.transitions_table (source_state_index, action_index)  && (Hashtbl.find state_space.transitions_table (source_state_index, action_index)) = state_index1 then (

				(* TO RECHECK (exception disabled by Etienne, 16/03/2012 *)
			
				(* Unexpected case *)
(* 				raise (InternalError ("Error when merging states: a couple '(source_state_index, action_index)' is already bound in the transitions table.")); *)
			)else
				Hashtbl.add state_space.transitions_table (source_state_index, action_index) state_index1;
		);
		(* Else do nothing *)
		)
	) transitions_copy;
	
	(*-------------------------------------------------------------*)
	(* Remove s2 from state hashtable *)
	(*-------------------------------------------------------------*)
	Hashtbl.remove state_space.all_states state_index2;
	
	(*-------------------------------------------------------------*)
	(* Replace s2 with s1 in states_for_comparison *)
	(*-------------------------------------------------------------*)
	(* Find the hash *)
	let hash2 = hash_code state2 in
	(* Get all states with that hash *)
	let all_states_with_hash2 = Hashtbl.find_all state_space.states_for_comparison hash2 in
	(* Remove them all *)
	while Hashtbl.mem state_space.states_for_comparison hash2 do
		Hashtbl.remove state_space.states_for_comparison hash2;
	done;
	(* Add them back *)
	List.iter (fun state_index ->
		(* Only add if not state2 *)
		if state_index != state_index2 then Hashtbl.add state_space.states_for_comparison hash2 state_index;
	) all_states_with_hash2;
	
	
	(* TO DO: remove merged state from states_for_comparison *)
	
	
(*	(* First copy the table (MEMORY CONSUMING! but necessary in order to avoid unexpected behaviors) *)
	let states_for_comparison_copy = Hashtbl.copy state_space.states_for_comparison in
	(* Empty the original hashtable *)
	Hashtbl.clear state_space.states_for_comparison;
	(* Fill it again *)
	Hashtbl.iter (fun hash state_index ->
		(* Replace the state if needed *)
		let new_state_index = if state_index = state_index2 then state_index1 else state_index in
		(* Add it *)
		Hashtbl.add hash new_state_index;
	) states_for_comparison_copy; *)
	()*)



(** Merge two states by replacing the second one by the first one, in the whole state_space structure (lists of states, and transitions) *)
let merge_states_ulrich state_space merger_state_index merged =
	(* NOTE: 'merged' is usually very small, e.g., 1 or 2, so no need to optimize functions using 'merged *) 
	print_message Verbose_high ("Merging: update tables for state '" ^ (string_of_int merger_state_index) ^ "' with " ^ (string_of_int (List.length merged)) ^ " merged.");
	
	(* Rebuild transitions table *)
	print_message Verbose_high ("Merging: update transition table, containing " ^ (string_of_int (Hashtbl.length state_space.transitions_table)) ^ " elements");
	let t' = Hashtbl.copy state_space.transitions_table in
	Hashtbl.clear state_space.transitions_table;
	Hashtbl.iter (fun (src, a) trg -> 
		let src' = if (List.mem src merged) then merger_state_index else src 
		and trg' = if (List.mem trg merged) then merger_state_index else trg in
		(* Add if not *)
		add_transition state_space (src', a, trg')
	) t';

	(* Remove merged from hash table *)
	print_message Verbose_high "Merging: update hash table";
	let the_state = get_state state_space merger_state_index in
	let h = hash_code the_state in
	(* Get all states with that hash *)
	let bucket = Hashtbl.find_all state_space.states_for_comparison h in
	print_message Verbose_high ("Merging: got " ^ (string_of_int (List.length bucket)) ^ " states with hash " ^ (string_of_int h));
	(* Remove them all *)
	while Hashtbl.mem state_space.states_for_comparison h do
		Hashtbl.remove state_space.states_for_comparison h;
	done;
	(* Add them back *)
	List.iter (fun y ->
		(* Only add if not to be merged *)
		if not (List.mem y merged) then Hashtbl.add state_space.states_for_comparison h y;
	) bucket;
	
	(* Remove merged from state table *)
	print_message Verbose_high "Merging: update state table";
	List.iter (fun s -> 
		print_message Verbose_high ("Merging: remove state " ^ (string_of_int s));
(*		while Hashtbl.mem state_space.states s do *)
			Hashtbl.remove state_space.all_states s;
			
			(* If the state was the initial state: replace with the merger state_index *)
			(*** WARNING: situation not much tested ***)
			if s = (get_initial_state_index state_space) then(
				print_message Verbose_low ("The initial state in the reachability state_space has been merged with another one.");
				state_space.initial <- Some merger_state_index;
			);
(*		done*)
	) merged
	


(* Get states sharing the same location and discrete values from hash_table, excluding s *)
let get_siblings state_space si =
	let s = get_state state_space si in
	let l, _ = s in
	let h = hash_code s in
	let sibs = Hashtbl.find_all state_space.states_for_comparison h in
	(* check for exact correspondence (=> hash collisions!), and exclude si *)
	List.fold_left (fun siblings sj ->
		if sj = si then siblings else begin 
			let l', c' = get_state state_space sj in
			if (Location.location_equal l l') then
				(sj, (l',c')) :: siblings
			else
				siblings
		end
	) [] sibs
	

(*module IntSet = Set.Make(
	struct
		type t = state_index
		let compare a b = compare a b
	end
)*)



(* Try to merge new states with existing ones. Returns list of merged states (ULRICH) *)
let merge state_space new_states =
	let mergeable = LinearConstraint.px_hull_assign_if_exact in
	
	(* function for merging one state with its siblings *)
	let merge_state si =
		print_message Verbose_total ("try to merge state " ^ (string_of_int si));
		let l, c = get_state state_space si in
		(* get merge candidates as pairs (index, state) *)
		let candidates = get_siblings state_space si in
		(* try to merge with siblings, restart if merge found, return eaten states *)
		let rec eat all_mc rest_mc = begin
			match rest_mc with
				| [] -> [] (* here, we are really done *)
				| m :: tail_mc -> begin
					let sj, (_, c') = m in
					if mergeable c c' then begin
						print_message Verbose_high ("merged with state " ^ (string_of_int sj));
						(* we ate sj, start over with new bigger state, removing sj *)
						let all_mc' = List.filter (fun (sk, _) -> sk <> sj) all_mc in
						sj :: eat all_mc' all_mc'
					end else begin
						(* try to eat the rest of them *)
						eat all_mc tail_mc
					end
				end
		end
		in
		eat candidates candidates
	in
	
	(* Iterate list of new states and try to merge them, return eaten states *)
	let rec main_merger states =
		match states with
			| [] -> []
			| s :: ss -> begin
					let eaten = merge_state s in
					if eaten = [] then
						(* nothing merged -> go on with the rest *)
						main_merger ss
					else begin
						(* update transitions and state table *)
						merge_states_ulrich state_space s eaten;
(*						List.iter (fun state_to_be_eaten -> 
							merge_2_states state_space s state_to_be_eaten
						) eaten;*)
						
						(* go on, skipping eaten states from the rest of the list *)
						(* Optimization: does not care of the order (otherwise use list_append *)
						List.rev_append eaten (main_merger (list_diff ss eaten))
					end
				end in
	
	(* Do it! *)
	let eaten = main_merger new_states in
	let nb_eaten = List.length eaten in
	let nb_orig = List.length new_states in
	if nb_eaten > 0 then
		print_message Verbose_standard ("  " ^ (string_of_int nb_eaten) ^ " state" ^ (s_of_int nb_eaten) ^ " merged within " ^ (string_of_int nb_orig) ^ " state" ^ (s_of_int nb_orig) ^ ".");
	
	(* return eaten states *)
	(*list_diff new_states*) eaten



(** Empties the hash table giving the set of states for a given location; optimization for the jobshop example, where one is not interested in comparing  a state of iteration n with states of iterations < n *)
let empty_states_for_comparison state_space =
	Hashtbl.clear state_space.states_for_comparison



(************************************************************)
(** Misc: tile natures *)
(************************************************************)
(** Convert a statespace_nature into a string *)
let string_of_statespace_nature = function
	| Good -> "good"
	| Bad -> "bad"
	| Unknown -> "unknown"
(* 	| _ -> raise (InternalError ("Tile nature should be good or bad only, so far ")) *)


	
(************************************************************)
(** Statistics *)
(************************************************************)


(** Get statistics on the number of comparisons between states *)
let get_statistics () =
	(string_of_int !nb_state_comparisons) ^ " comparison" ^ (s_of_int !nb_state_comparisons) ^ " between states were performed."
	^ "\n" ^ (string_of_int !nb_constraint_comparisons) ^ " comparison" ^ (s_of_int !nb_constraint_comparisons) ^ " between constraints were performed."


(** Get statistics on the structure of the states: number of different locations, number of different constraints *)
let get_statistics_states state_space =
	let nb_states = nb_states state_space in
	(* Compute the number of constraints per location *)
	let nb_constraints_per_location_id = Hashtbl.create (DynArray.length state_space.locations) in
	(* Compute the number of constraints equal to each other (list of couples (constraint, nb) )*)
	let nb_per_constraint = DynArray.make 0 in
	(* Iterate on all states *)
	iterate_on_states (fun _ (location_index, the_constraint) ->
		(* Find former nb of constraints for this location *)
		let former_nb = try
			Hashtbl.find nb_constraints_per_location_id location_index
		with Not_found -> 0 in
		(* Add +1 *)
		Hashtbl.replace nb_constraints_per_location_id location_index (former_nb + 1);
		
		(*(* Find former nb of constraints *)
		let _ =
		try(
			(* Iterate on the array *)
			DynArray.iteri (fun array_index (current_constraint, current_nb) ->
				if LinearConstraint.is_equal the_constraint current_constraint then(
					DynArray.set nb_per_constraint array_index (the_constraint, current_nb + 1);
					(* Found index *)
					raise (Found 0 (*(don't care) *));
				);
			) nb_per_constraint;
			(* If here: not found, i.e., new index *)
			DynArray.add nb_per_constraint (the_constraint, 1);
		)
		with Found _ -> ();
		in ();*)
	) state_space;
	
	let nb_locations = Hashtbl.length nb_constraints_per_location_id in
	let nb_different_constraints = DynArray.length nb_per_constraint in
	let result_string = ref (
		(string_of_int nb_states) ^ " state" ^ (s_of_int nb_states) ^ ", " ^ (string_of_int nb_locations) ^ " location" ^ (s_of_int nb_locations) ^ ", " ^ (string_of_int nb_different_constraints) ^ " constraint" ^ (s_of_int nb_different_constraints) ^ ""
		^ "\nNumber of constraints per locations:"
	) in
	
	(* Add number of constraints per location *)
	Hashtbl.iter (fun location nb_constraints ->
		result_string := !result_string ^ " - " ^ (string_of_int nb_constraints);
	) nb_constraints_per_location_id;
	(* Add average *)
	result_string := !result_string ^ "\nAverage: " ^ (round3_float ((float_of_int nb_states) /. (float_of_int nb_locations)));
	(*
	(* Add number per constraint *)
	result_string := !result_string ^ "\nNumber of occurrence of constraints: ";
	DynArray.iter (fun (the_constraint , nb_constraints) ->
		result_string := !result_string ^ " - " ^ (string_of_int nb_constraints);
	) nb_per_constraint;
	(* Add average *)
	result_string := !result_string ^ "\nAverage: " ^ (string_of_float ((float_of_int nb_different_constraints) /. (float_of_int nb_states)));
	*)
	(* Return result *)
	!result_string
	
	
	
(*(** Get the number of comparisons between states (performance checking purpose) *)
let get_nb_state_comparisons () =
(*	print_message Verbose_standard ("About to return the number of comparisons (" ^ (string_of_int !nb_state_comparisons) ^ ").");*)
	!nb_state_comparisons

(** Get the number of comparisons between constraints (performance checking purpose) *)
let get_nb_constraint_comparisons () =
	!nb_constraint_comparisons*)

