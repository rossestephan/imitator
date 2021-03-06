(************************************************************
 *
 *                       IMITATOR
 * 
 * LIPN, Université Paris 13, Sorbonne Paris Cité (France)
 * 
 * Module description: main virtual class to explore the state space: only defines post-related function, i.e., to compute the successor states of ONE state
 * 
 * File contributors : Étienne André
 * Created           : 2015/12/02
 * Last modified     : 2016/05/03
 *
 ************************************************************)


(**************************************************************)
(* Modules *)
(**************************************************************)
open ImitatorUtilities
open AlgoGeneric
open State

(**************************************************************)
(* Class-independent functions *)
(**************************************************************)
val compute_initial_state_or_abort : unit -> State.state

(*------------------------------------------------------------*)
(** Apply time elapsing in location to the_constraint (the location is needed to retrieve the stopwatches stopped in this location) *)
(*------------------------------------------------------------*)
(* val apply_time_elapsing : Location.global_location -> LinearConstraint.pxd_linear_constraint -> unit *)

(*------------------------------------------------------------*)
(** Apply time past in location to the_constraint (the location is needed to retrieve the stopwatches stopped in this location) *)
(*------------------------------------------------------------*)
val apply_time_past : Location.global_location -> LinearConstraint.pxd_linear_constraint -> unit


(**************************************************************)
(* Class definition *)
(**************************************************************)
class virtual algoStateBased :
	object inherit algoGeneric

		(************************************************************)
		(* Class variables *)
		(************************************************************)
		
		(* Start time for the algorithm *)
		val mutable start_time : float

		
		(* Name of the algorithm (to be defined in subclasses) *)
		method virtual algorithm_name : string
		
		(* Nature of the state space according to a property *)
		val mutable statespace_nature : StateSpace.statespace_nature

		
		(************************************************************)
		(* Class methods *)
		(************************************************************)
		
		(* Write a message preceeded by "[algorithm_name]" *)
		method print_algo_message : verbose_mode -> string -> unit
		
		(* Write a message preceeded by "\n[algorithm_name]" *)
		method print_algo_message_newline : verbose_mode -> string -> unit
		
		(* Variable initialization (to be defined in subclasses) *)
		method initialize_variables : unit
		
		(* Update the nature of the trace set *)
		method update_statespace_nature : State.state -> unit
		
		(*------------------------------------------------------------*)
		(* Add a new state to the reachability_graph (if indeed needed) *)
		(* Side-effects: modify new_states_indexes *)
		(*** TODO: move new_states_indexes to a variable of the class ***)
		(* Return true if the state is not discarded by the algorithm, i.e., if it is either added OR was already present before *)
		(*------------------------------------------------------------*)
		(*** TODO: simplify signature by removing the StateSpace, the state_index list ref and the action_index, and by returning the list of actually added states ***)
		method virtual add_a_new_state : StateSpace.state_space -> state_index -> state_index list ref -> Automaton.action_index -> Location.global_location -> LinearConstraint.px_linear_constraint -> bool
		
		(* Actions to perform when meeting a state with no successors: virtual method to be defined in subclasses *)
		method virtual process_deadlock_state : state_index -> unit
		
		(* Compute the list of successor states of a given state, and update the state space; returns the list of new states' indexes actually added *)
		(** TODO: to get a more abstract method, should get rid of the state space, and update the state space from another function ***)
		method post_from_one_state : StateSpace.state_space -> state_index -> state_index list

		(* Main method to run the algorithm: virtual method to be defined in subclasses *)
		method virtual run : unit -> Result.imitator_result
		
(************************************************************)
(************************************************************)
end
(************************************************************)
(************************************************************)
